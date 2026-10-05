import SwiftUI
import GlobeRenderingSpike

/// App shell. Currently hosts the Milestone 1 renderer spike directly
/// so it's visible on launch — this view is replaced by the real
/// globe screen (Milestone 3+) once a renderer is chosen for real and
/// a licensed dataset (Milestone 2) replaces the placeholder outlines.
@main
struct AtlasDesktopApp: App {
    var body: some Scene {
        WindowGroup("Atlas Desktop — Milestone 1 Spike") {
            SceneKitGlobeSpikeView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .windowResizability(.contentSize)
    }
}
