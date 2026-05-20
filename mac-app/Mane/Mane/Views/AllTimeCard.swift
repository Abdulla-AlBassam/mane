import SwiftUI
import Charts

struct AllTimeCard: View {
    let total: Int
    let buckets: [(label: String, total: Int, date: Date)]
    @Binding var period: AllTimePeriod

    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("All time")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                periodPicker
            }
            Text(Self.decimal.string(from: NSNumber(value: total)) ?? "\(total)")
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            chart.frame(height: 110)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground()
    }

    private var periodPicker: some View {
        Picker("", selection: $period) {
            ForEach(AllTimePeriod.allCases) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
        .labelsHidden()
    }

    @ViewBuilder
    private var chart: some View {
        let hasData = buckets.contains(where: { $0.total > 0 })
        if !hasData {
            VStack {
                Spacer()
                Text("No blocks recorded in this period yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            Chart {
                ForEach(Array(buckets.enumerated()), id: \.offset) { idx, bucket in
                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Blocks", bucket.total)
                    )
                    .foregroundStyle(idx == buckets.count - 1 ? Color.accentColor : Color.accentColor.opacity(0.45))
                    .cornerRadius(3)
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}
