import SwiftUI
import Charts

struct TodayCard: View {
    let total: Int
    let byHour: [Int]

    private var peakHour: Int? {
        let m = byHour.max() ?? 0
        guard m > 0 else { return nil }
        return byHour.firstIndex(of: m)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                if let peakHour {
                    Text("peak \(formatHour(peakHour))")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Text("\(total)")
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

    @ViewBuilder
    private var chart: some View {
        let hasHourly = (byHour.max() ?? 0) > 0
        if hasHourly {
            Chart {
                ForEach(0..<24, id: \.self) { hour in
                    BarMark(
                        x: .value("Hour", hour),
                        y: .value("Blocks", byHour[hour])
                    )
                    .foregroundStyle(barColor(for: hour))
                    .cornerRadius(2)
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let h = value.as(Int.self) {
                            Text(formatHour(h))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
        } else if total > 0 {
            VStack {
                Spacer()
                Text("Hourly breakdown will populate on the next page load.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack {
                Spacer()
                Text("Activity will appear here as you browse.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func barColor(for hour: Int) -> Color {
        if let peak = peakHour, hour == peak {
            return Color.accentColor
        }
        return Color.accentColor.opacity(0.45)
    }

    private func formatHour(_ hour: Int) -> String {
        var c = DateComponents()
        c.hour = hour
        let d = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f.string(from: d).lowercased()
    }
}
