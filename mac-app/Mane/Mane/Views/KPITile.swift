import SwiftUI

struct KPITile: View {
    let title: String
    let value: String
    let caption: String?

    init(_ title: String, value: String, caption: String? = nil) {
        self.title = title
        self.value = value
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption ?? " ")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground()
    }
}
