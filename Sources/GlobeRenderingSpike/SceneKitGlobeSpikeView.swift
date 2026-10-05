import SwiftUI
import SceneKit

/// Hosts the spike SceneKit scene for manual visual verification on a
/// real Mac. `allowsCameraControl` is used here only because this is
/// a throwaway spike — real drag rotation/zoom with bounds is
/// Milestone 3's `CountrySelectionService`/camera work, not this.
public struct SceneKitGlobeSpikeView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SceneKitGlobeSceneBuilder.makeScene()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .black
        return view
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {}
}
