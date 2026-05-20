import SwiftUI

struct DomainsCard: View {
    let companies: [CompanyStat]
    let onViewAll: () -> Void
    let onSelect: (CompanyStat) -> Void

    private var maxCount: Int { max(companies.map(\.count).max() ?? 1, 1) }
    private var totalCompanies: Int { companies.count }

    var body: some View {
        Card("Top blocked companies") {
            if companies.isEmpty {
                Text("Blocked companies will appear after the first ad or tracker is intercepted.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(companies.prefix(8)) { company in
                        Button {
                            onSelect(company)
                        } label: {
                            CompanyRow(company: company, maxCount: maxCount)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Spacer()
                        Button {
                            onViewAll()
                        } label: {
                            HStack(spacing: 6) {
                                Text("View all \(totalCompanies) companies")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                        }
                        .buttonStyle(GlassPillButtonStyle())
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

struct CompanyRow: View {
    let company: CompanyStat
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(company.name)
                    .font(.system(.callout, design: .default).weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                CategoryPill(category: company.dominantCategory)
                Spacer()
                Text("\(company.count)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            BarTrack(value: company.count, max: maxCount)
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(domainSummary)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .contentShape(.rect)
    }

    private var domainSummary: String {
        let topDomains = company.domains.prefix(2).map(\.domain).joined(separator: ", ")
        let remaining = company.domains.count - 2
        if remaining > 0 {
            return "\(topDomains) + \(remaining) more"
        }
        return topDomains
    }
}

struct CategoryPill: View {
    let category: TrackerCategory

    var body: some View {
        Text(category.rawValue)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(category.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(category.tint.opacity(0.14))
            )
            .overlay(
                Capsule().strokeBorder(category.tint.opacity(0.35), lineWidth: 0.5)
            )
    }
}

struct BarTrack: View {
    let value: Int
    let max: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.95),
                                Color.accentColor.opacity(0.55)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max > 0 ? geo.size.width * CGFloat(value) / CGFloat(max) : 0)
            }
        }
        .frame(height: 6)
    }
}

struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(.secondary)
            .glassPillBackground()
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func glassPillBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: .capsule)
        } else {
            self
                .background(.thinMaterial, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        }
    }
}
