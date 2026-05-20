import SwiftUI

struct AdvancedSheet: View {
    @ObservedObject var model: DashboardModel
    @Environment(\.dismiss) private var dismiss

    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            HStack(spacing: 12) {
                KPITile(
                    "Rules active",
                    value: Self.decimal.string(from: NSNumber(value: model.ruleCount)) ?? "—",
                    caption: "EasyList + EasyPrivacy"
                )
                KPITile(
                    "Filter lists",
                    value: "\(model.filterLists.count)",
                    caption: "loaded into the engine"
                )
            }
            FilterListsCard(lists: model.filterLists, compiledAt: model.compiledAt)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 640, height: 460)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Engine details")
                    .font(.title2.weight(.semibold))
                Text("How Mane is configured under the hood")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(GlassCircleButtonStyle())
            .help("Close")
        }
    }
}
