import SceneKit
import AppKit
import AtlasDesktopCore

/// Builds a minimal SceneKit scene: a sphere plus line-geometry
/// outlines for the placeholder landmasses, using SphereProjection so
/// the eventual hit-testing spike can reuse the exact same transform.
/// Spike-only — see docs/adr/0002-renderer-choice.md.
public enum SceneKitGlobeSceneBuilder {
    public static func makeScene() -> SCNScene {
        let scene = SCNScene()

        let sphere = SCNSphere(radius: 1.0)
        sphere.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        sphere.firstMaterial?.specular.contents = NSColor(white: 0.3, alpha: 1.0)
        sphere.segmentCount = 64
        let sphereNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(sphereNode)

        for outline in [PlaceholderOutlines.roughIslandOutline(), PlaceholderOutlines.roughPeninsulaOutline()] {
            sphereNode.addChildNode(outlineNode(for: outline))
        }

        let light = SCNLight()
        light.type = .omni
        light.intensity = 900
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(3, 3, 3)
        scene.rootNode.addChildNode(lightNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 250
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        return scene
    }

    private static func outlineNode(for coordinates: [Coordinate]) -> SCNNode {
        // Lift the outline slightly above the sphere surface so it
        // doesn't z-fight with the sphere geometry.
        let liftedRadius = 1.004
        let points = coordinates.map { coord -> SCNVector3 in
            let p = SphereProjection.point(for: coord, radius: liftedRadius)
            return SCNVector3(Float(p.x), Float(p.y), Float(p.z))
        }

        let source = SCNGeometrySource(vertices: points)
        var indices: [Int32] = []
        for i in 0..<(points.count - 1) {
            indices.append(Int32(i))
            indices.append(Int32(i + 1))
        }
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .line,
            primitiveCount: indices.count / 2,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = NSColor.systemYellow
        geometry.firstMaterial?.lightingModel = .constant
        return SCNNode(geometry: geometry)
    }
}
