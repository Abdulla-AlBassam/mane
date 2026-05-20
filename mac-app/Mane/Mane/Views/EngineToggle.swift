import SwiftUI

struct EngineToggle: View {
    @Binding var enabled: Bool

    var body: some View {
        Toggle("Engine", isOn: $enabled)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.large)
            .tint(.green)
            .help(enabled ? "Engine on. Click to pause blocking." : "Engine paused. Click to resume.")
    }
}
