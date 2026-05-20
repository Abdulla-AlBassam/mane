import SwiftUI

struct DashboardView: View {
    @StateObject private var model = DashboardModel()
    @State private var period: AllTimePeriod = .week
    @State private var showAdvanced = false
    @State private var showAllDomains = false
    @State private var initialCompany: CompanyStat? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeaderBar(model: model, showAdvanced: $showAdvanced)
                HStack(alignment: .top, spacing: 16) {
                    TodayCard(total: model.todayBlocks, byHour: model.todayByHour)
                        .frame(maxWidth: .infinity)
                    AllTimeCard(
                        total: model.totalBlocks,
                        buckets: model.allTimeBuckets(for: period),
                        period: $period
                    )
                    .frame(maxWidth: .infinity)
                }
                DomainsCard(
                    companies: model.topCompanies,
                    onViewAll: {
                        initialCompany = nil
                        showAllDomains = true
                    },
                    onSelect: { company in
                        initialCompany = company
                        showAllDomains = true
                    }
                )
            }
            .padding(32)
            .frame(maxWidth: 1200, alignment: .top)
        }
        .frame(minWidth: 820, idealWidth: 1040, minHeight: 600, idealHeight: 760)
        .background(atmosphere)
        .containerBackground(.regularMaterial, for: .window)
        .navigationTitle("Mane")
        .sheet(isPresented: $showAdvanced) {
            AdvancedSheet(model: model)
        }
        .sheet(isPresented: $showAllDomains) {
            DomainsSheet(
                companies: model.allCompanies,
                domains: model.allDomains,
                initialCompany: initialCompany
            )
        }
    }

    private var atmosphere: some View {
        ZStack {
            RadialGradient(
                colors: [Color.accentColor.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 600
            )
            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.45, blue: 0.85).opacity(0.12),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 80,
                endRadius: 700
            )
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    DashboardView()
}
