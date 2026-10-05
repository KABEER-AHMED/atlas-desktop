import SwiftUI
import AtlasDesktopCore

/// Milestone 0 app shell: launches a window. No renderer, no data
/// pipeline, no presentation mode yet — those are later milestones
/// per docs/IMPLEMENTATION_PLAN.md. This target exists to prove the
/// package builds and launches as a native macOS app.
@main
struct AtlasDesktopApp: App {
    var body: some Scene {
        WindowGroup("Atlas Desktop") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
