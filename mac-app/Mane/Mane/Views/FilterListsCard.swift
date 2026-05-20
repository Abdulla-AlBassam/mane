import SwiftUI

struct FilterListsCard: View {
    let lists: [FilterListMeta]
    let compiledAt: Date?

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        Card("Filter lists") {
            if lists.isEmpty {
                Text("No filter lists found in the bundle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(lists) { list in
                        listRow(list)
                    }
                    if let compiledAt {
                        Divider().overlay(Color.primary.opacity(0.05))
                        HStack {
                            Text("Last compiled")
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(compiledAt, style: .relative)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
    }

    private func listRow(_ list: FilterListMeta) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(byteFormatter.string(fromByteCount: list.byteCount))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(list.updatedAt, style: .relative)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
