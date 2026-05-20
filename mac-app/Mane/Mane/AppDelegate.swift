import SwiftUI

@main
struct ManeApp: App {
    var body: some Scene {
        WindowGroup("Mane") {
            DashboardView()
        }
        .windowResizability(.contentSize)
    }
}
