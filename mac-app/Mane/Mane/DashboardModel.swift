import Foundation
import SwiftUI
import Combine

struct FilterListMeta: Codable, Identifiable, Hashable {
    let name: String
    let filename: String
    let updatedAtUnix: TimeInterval
    let byteCount: Int64

    var id: String { filename }
    var updatedAt: Date { Date(timeIntervalSince1970: updatedAtUnix) }
}

struct FilterListsManifest: Codable {
    let ruleCount: Int
    let skipped: Int
    let compiledAtUnix: TimeInterval
    let lists: [FilterListMeta]

    var compiledAt: Date { Date(timeIntervalSince1970: compiledAtUnix) }
}

struct DayStat: Identifiable, Hashable {
    let day: String
    let total: Int
    let byDomain: [String: Int]
    let byHour: [Int]
    var id: String { day }

    var date: Date? {
        DashboardModel.utcDayFormatter.date(from: day)
    }
}

struct DomainStat: Identifiable, Hashable {
    let domain: String
    let count: Int
    var id: String { domain }
    var category: TrackerCategory { TrackerTaxonomy.info(for: domain).category }
    var parent: String { TrackerTaxonomy.info(for: domain).parent }
}

struct CompanyStat: Identifiable {
    let name: String
    let count: Int
    let dominantCategory: TrackerCategory
    let categoryBreakdown: [TrackerCategory: Int]
    let domains: [DomainStat]
    var id: String { name }
}

enum AllTimePeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    var id: String { rawValue }
}

@MainActor
final class DashboardModel: ObservableObject {
    @Published private(set) var ruleCount: Int = 0
    @Published private(set) var skipped: Int = 0
    @Published private(set) var compiledAt: Date? = nil
    @Published private(set) var filterLists: [FilterListMeta] = []
    @Published private(set) var totalBlocks: Int = 0
    @Published private(set) var todayBlocks: Int = 0
    @Published private(set) var timeSeries: [DayStat] = []
    @Published private(set) var todayByHour: [Int] = Array(repeating: 0, count: 24)
    @Published private(set) var topDomains: [DomainStat] = []
    @Published private(set) var allDomains: [DomainStat] = []
    @Published private(set) var topCompanies: [CompanyStat] = []
    @Published private(set) var allCompanies: [CompanyStat] = []
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var hasLiveStats: Bool = false

    @Published var engineEnabled: Bool {
        didSet {
            guard !syncingFromDisk else { return }
            writeControl()
            print("[Mane] toggle -> \(engineEnabled)")
        }
    }

    private var pollTask: Task<Void, Never>?
    private var controlPollTask: Task<Void, Never>?
    private var syncingFromDisk = false

    private static let appGroup = "group.com.albassam.mane"
    private static let containerURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    private static let controlFileURL: URL? = containerURL?
        .appendingPathComponent("mane-control.json")
    private static let statsFileURL: URL? = containerURL?
        .appendingPathComponent("mane-stats.json")

    static let utcDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        self.engineEnabled = Self.readControlFromDisk()
        loadManifest()
        loadStats()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                self?.loadStats()
            }
        }
        controlPollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.syncControlFromDisk()
            }
        }
    }

    deinit {
        pollTask?.cancel()
        controlPollTask?.cancel()
    }

    private func syncControlFromDisk() {
        let external = Self.readControlFromDisk()
        guard external != engineEnabled else { return }
        syncingFromDisk = true
        engineEnabled = external
        syncingFromDisk = false
    }

    func reloadNow() {
        loadStats()
    }

    private func loadManifest() {
        guard let url = Bundle.main.url(forResource: "filterlists-meta", withExtension: "json") else {
            print("[Mane] filterlists-meta.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(FilterListsManifest.self, from: data)
            ruleCount = manifest.ruleCount
            skipped = manifest.skipped
            compiledAt = manifest.compiledAt
            filterLists = manifest.lists
        } catch {
            print("[Mane] failed to load filterlists-meta: \(error)")
        }
    }

    private func writeControl() {
        guard let url = Self.controlFileURL else { return }
        let payload: [String: Any] = ["enabled": engineEnabled]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private static func readControlFromDisk() -> Bool {
        guard let url = controlFileURL,
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let enabled = json["enabled"] as? Bool else {
            return true
        }
        return enabled
    }

    private func loadStats() {
        guard let url = Self.statsFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            hasLiveStats = false
            return
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let days = json["days"] as? [String: [String: Any]] else { return }

            var series: [DayStat] = []
            var total = 0
            var aggDomains: [String: Int] = [:]
            let todayKey = Self.utcDayFormatter.string(from: Date())
            var todayTotal = 0
            var todayHours = Array(repeating: 0, count: 24)

            for (day, content) in days.sorted(by: { $0.key < $1.key }) {
                let dayTotal = content["total"] as? Int ?? 0
                let byDomain = content["byDomain"] as? [String: Int] ?? [:]
                let byHour = (content["byHour"] as? [Int]) ?? Array(repeating: 0, count: 24)
                series.append(DayStat(day: day, total: dayTotal, byDomain: byDomain, byHour: byHour))
                total += dayTotal
                for (domain, count) in byDomain {
                    aggDomains[domain, default: 0] += count
                }
                if day == todayKey {
                    todayTotal = dayTotal
                    todayHours = byHour.count == 24 ? byHour : todayHours
                }
            }

            let sortedDomains = aggDomains
                .sorted { $0.value > $1.value }
                .map { DomainStat(domain: $0.key, count: $0.value) }
            let topN = Array(sortedDomains.prefix(8))
            let companies = Self.groupByCompany(sortedDomains)

            timeSeries = series
            totalBlocks = total
            todayBlocks = todayTotal
            todayByHour = todayHours
            topDomains = topN
            allDomains = sortedDomains
            topCompanies = Array(companies.prefix(8))
            allCompanies = companies
            lastUpdated = Date()
            hasLiveStats = total > 0 || !series.isEmpty
        } catch {
            print("[Mane] failed to load stats: \(error)")
        }
    }

    private static func groupByCompany(_ domains: [DomainStat]) -> [CompanyStat] {
        var bucket: [String: (count: Int, cats: [TrackerCategory: Int], domains: [DomainStat])] = [:]
        for stat in domains {
            let info = TrackerTaxonomy.info(for: stat.domain)
            var entry = bucket[info.parent] ?? (count: 0, cats: [:], domains: [])
            entry.count += stat.count
            entry.cats[info.category, default: 0] += stat.count
            entry.domains.append(stat)
            bucket[info.parent] = entry
        }
        return bucket.map { name, agg in
            let dominant = agg.cats.max(by: { $0.value < $1.value })?.key ?? .other
            return CompanyStat(
                name: name,
                count: agg.count,
                dominantCategory: dominant,
                categoryBreakdown: agg.cats,
                domains: agg.domains.sorted { $0.count > $1.count }
            )
        }
        .sorted { $0.count > $1.count }
    }

    func allTimeBuckets(for period: AllTimePeriod) -> [(label: String, total: Int, date: Date)] {
        let cal = Calendar.current
        let now = Date()
        let dayDates = timeSeries.compactMap { stat -> (Date, Int)? in
            guard let d = stat.date else { return nil }
            return (cal.startOfDay(for: d), stat.total)
        }
        let totalsByDay = Dictionary(grouping: dayDates, by: { $0.0 })
            .mapValues { entries in entries.reduce(0) { $0 + $1.1 } }

        switch period {
        case .week:
            // last 7 days, one bar per day
            return (0..<7).reversed().compactMap { offset in
                guard let d = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now)) else { return nil }
                let total = totalsByDay[d] ?? 0
                let f = DateFormatter()
                f.dateFormat = "EEE"
                return (label: f.string(from: d), total: total, date: d)
            }
        case .month:
            // last 30 days as ~6 5-day windows
            let windows = 6
            let windowSize = 5
            return (0..<windows).reversed().compactMap { idx in
                guard let end = cal.date(byAdding: .day, value: -idx * windowSize, to: cal.startOfDay(for: now)),
                      let start = cal.date(byAdding: .day, value: -(windowSize - 1), to: end) else { return nil }
                let total = totalsByDay
                    .filter { $0.key >= start && $0.key <= end }
                    .reduce(0) { $0 + $1.value }
                let f = DateFormatter()
                f.dateFormat = "d MMM"
                return (label: f.string(from: end), total: total, date: end)
            }
        case .year:
            // last 12 months
            return (0..<12).reversed().compactMap { offset in
                guard let target = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
                let comps = cal.dateComponents([.year, .month], from: target)
                let total = totalsByDay
                    .filter {
                        let c = cal.dateComponents([.year, .month], from: $0.key)
                        return c.year == comps.year && c.month == comps.month
                    }
                    .reduce(0) { $0 + $1.value }
                let f = DateFormatter()
                f.dateFormat = "MMM"
                return (label: f.string(from: target), total: total, date: target)
            }
        }
    }
}
