import SwiftUI

enum DomainsSheetGrouping: String, CaseIterable, Identifiable {
    case company = "By company"
    case domain = "By domain"
    var id: String { rawValue }
}

struct DomainsSheet: View {
    let companies: [CompanyStat]
    let domains: [DomainStat]
    let initialCompany: CompanyStat?
    @Environment(\.dismiss) private var dismiss
    @State private var grouping: DomainsSheetGrouping = .company
    @State private var searchText: String = ""
    @State private var expandedCompany: String?

    init(companies: [CompanyStat], domains: [DomainStat], initialCompany: CompanyStat? = nil) {
        self.companies = companies
        self.domains = domains
        self.initialCompany = initialCompany
        _expandedCompany = State(initialValue: initialCompany?.name)
    }

    private var maxDomainCount: Int { max(domains.map(\.count).max() ?? 1, 1) }
    private var maxCompanyCount: Int { max(companies.map(\.count).max() ?? 1, 1) }

    private var filteredCompanies: [CompanyStat] {
        guard !searchText.isEmpty else { return companies }
        let q = searchText.lowercased()
        return companies.filter {
            $0.name.lowercased().contains(q) ||
                $0.domains.contains(where: { $0.domain.lowercased().contains(q) })
        }
    }

    private var filteredDomains: [DomainStat] {
        guard !searchText.isEmpty else { return domains }
        let q = searchText.lowercased()
        return domains.filter { $0.domain.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    switch grouping {
                    case .company:
                        ForEach(filteredCompanies) { c in
                            expandableCompanyRow(c)
                        }
                    case .domain:
                        ForEach(filteredDomains) { d in
                            DomainListRow(stat: d, maxCount: maxDomainCount)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(24)
        .frame(width: 760, height: 620)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Blocked traffic")
                    .font(.title2.weight(.semibold))
                Text("\(companies.count) companies, \(domains.count) domains since install")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(GlassCircleButtonStyle())
            .help("Close")
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $grouping) {
                ForEach(DomainsSheetGrouping.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .labelsHidden()
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func expandableCompanyRow(_ company: CompanyStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                    expandedCompany = expandedCompany == company.name ? nil : company.name
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: expandedCompany == company.name ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                    Text(company.name)
                        .font(.system(.body).weight(.medium))
                        .foregroundStyle(.primary)
                    CategoryPill(category: company.dominantCategory)
                    Spacer()
                    Text("\(company.count)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .buttonStyle(.plain)
            BarTrack(value: company.count, max: maxCompanyCount)
                .padding(.leading, 22)
            if expandedCompany == company.name {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(company.domains) { d in
                        DomainListRow(stat: d, maxCount: company.domains.first?.count ?? 1)
                    }
                }
                .padding(.leading, 22)
                .padding(.top, 4)
            }
        }
    }
}

struct DomainListRow: View {
    let stat: DomainStat
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(stat.domain)
                    .font(.system(.callout))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                CategoryPill(category: stat.category)
                Spacer()
                Text("\(stat.count)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            BarTrack(value: stat.count, max: maxCount)
        }
    }
}

struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .glassCircleBackground()
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func glassCircleBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: .circle)
        } else {
            self
                .background(.thinMaterial, in: .circle)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        }
    }
}
