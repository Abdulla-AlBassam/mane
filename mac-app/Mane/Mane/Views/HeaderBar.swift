import SwiftUI

struct HeaderBar: View {
    @ObservedObject var model: DashboardModel
    @Binding var showAdvanced: Bool
    @State private var refreshSpin: Double = 0

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("LargeIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 80, height: 80)
                .shadow(color: .white.opacity(0.18), radius: 16)
            EngineToggle(enabled: $model.engineEnabled)
            Spacer()
            rightCluster
        }
    }

    @ViewBuilder
    private var rightCluster: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    refreshButton
                    updatedTimer
                    advancedButton
                }
            }
        } else {
            HStack(spacing: 10) {
                refreshButton
                updatedTimer
                advancedButton
            }
        }
    }

    private var refreshButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.6)) {
                refreshSpin += 360
            }
            model.reloadNow()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .rotationEffect(.degrees(refreshSpin))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(GlassCircleButtonStyle())
        .help("Refresh stats")
    }

    @ViewBuilder
    private var updatedTimer: some View {
        Group {
            if let lastUpdated = model.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative)")
            } else {
                Text("Loading…")
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.tertiary)
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .glassPillBackground()
    }

    private var advancedButton: some View {
        Button {
            showAdvanced = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(GlassCircleButtonStyle())
        .help("Engine details")
    }
}
