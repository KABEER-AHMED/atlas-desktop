import AppKit
import SceneKit
import Foundation
import AtlasDesktopCore
import os

/// Owns the SceneKit scene: node graph, materials, lights, labels, and
/// the mapping from `CameraState` onto transforms.
///
/// It holds no product state of its own. Everything it draws is pushed
/// in through `apply(...)`, so the globe can be reasoned about (and the
/// geometry, layout and transforms tested) without a window.
///
/// Layer stack, innermost first — each layer's radius comes from
/// `GlobeTheme` so nothing z-fights at the zoom limits:
/// surface fill → selection tint → borders → selection marker → labels,
/// with the atmospheric rim drawn last as an additive billboard.
@MainActor
public final class GlobeSceneController {
    private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "renderer")

    public let scene = SCNScene()
    public let theme: GlobeTheme

    /// Rotated by the camera state; everything geographic hangs off it.
    private let globeNode = SCNNode()
    private let surfaceNode = SCNNode()
    private let selectionNode = SCNNode()
    private let borderNode = SCNNode()
    private let selectedBorderNode = SCNNode()
    private let selectionMarkerNode = SCNNode()
    private let labelRootNode = SCNNode()
    private let atmosphereNode = SCNNode()

    public let cameraNode = SCNNode()
    private let sunLightNode = SCNNode()
    private let ambientLightNode = SCNNode()

    private var dataset: GeographyDataset?
    private var indexMap: CountryIndexMap?
    private var labelNodes: [CountryID: SCNNode] = [:]
    private var visibleLabelIDs: Set<CountryID> = []
    private var labelsEnabled = true
    private var selectedID: CountryID?
    private var lastLabelLayoutCamera: CameraState?
    private var hasSurfaceImagery = false

    public init(theme: GlobeTheme = .standard) {
        self.theme = theme
        buildStaticScene()
    }

    // MARK: - Scene construction

    private func buildStaticScene() {
        // A star field rather than a flat fill: a plain dark rectangle
        // behind the globe reads as "no background" rather than as
        // space. It is a spherical environment, so the stars stay fixed
        // while the globe turns under them.
        scene.background.contents = GlobeTextureFactory.starField(theme: theme) ?? theme.space

        let sphere = SCNSphere(radius: GlobeTheme.surfaceRadius)
        // 96 segments: the silhouette is smooth at the closest zoom
        // without the vertex count of a higher tessellation, which
        // would buy nothing — the land shapes come from the texture and
        // the border lines, not the sphere.
        sphere.segmentCount = 96
        let surfaceMaterial = SCNMaterial()
        // Photographic surface imagery. When it is unavailable the globe
        // still draws, with the flat ocean colour underneath and the
        // generated land texture on top (see `install(resources:)`).
        let imagery = EarthImagery.load()
        hasSurfaceImagery = imagery != nil
        surfaceMaterial.diffuse.contents = imagery ?? theme.ocean
        surfaceMaterial.diffuse.wrapS = .repeat
        surfaceMaterial.diffuse.mipFilter = .linear
        surfaceMaterial.lightingModel = .lambert
        // Specular highlight suppressed: a glossy sphere reads as a
        // plastic ball, and it would sit on top of the terminator.
        surfaceMaterial.specular.contents = NSColor.black
        surfaceMaterial.locksAmbientWithDiffuse = true
        sphere.materials = [surfaceMaterial]
        surfaceNode.geometry = sphere
        surfaceNode.renderingOrder = 0

        let selectionSphere = SCNSphere(radius: GlobeTheme.selectionRadius)
        selectionSphere.segmentCount = 96
        let selectionMaterial = SCNMaterial()
        selectionMaterial.lightingModel = .lambert
        selectionMaterial.specular.contents = NSColor.black
        selectionMaterial.transparencyMode = .aOne
        selectionMaterial.writesToDepthBuffer = false
        selectionSphere.materials = [selectionMaterial]
        selectionNode.geometry = selectionSphere
        selectionNode.renderingOrder = 5
        selectionNode.isHidden = true

        borderNode.renderingOrder = 10
        selectedBorderNode.renderingOrder = 12
        selectionMarkerNode.renderingOrder = 14
        labelRootNode.renderingOrder = 20

        globeNode.addChildNode(surfaceNode)
        globeNode.addChildNode(selectionNode)
        globeNode.addChildNode(borderNode)
        globeNode.addChildNode(selectedBorderNode)
        globeNode.addChildNode(selectionMarkerNode)
        globeNode.addChildNode(labelRootNode)
        scene.rootNode.addChildNode(globeNode)

        buildAtmosphere()
        buildLights()
        buildCamera()
    }

    private func buildAtmosphere() {
        // A billboarded additive quad rather than a shell of geometry:
        // one quad, no depth interaction, and the glow stays centred on
        // the silhouette at every zoom level. The quad is slightly
        // larger than the globe, and the gradient is told exactly where
        // the globe's edge falls inside it.
        let halfWidth = GlobeTheme.atmosphereRadius
        guard let gradient = GlobeTextureFactory.atmosphereGradient(
            limbRadius: GlobeTheme.surfaceRadius / halfWidth,
            theme: theme
        ) else { return }
        let size = halfWidth * 2
        let plane = SCNPlane(width: size, height: size)
        let material = SCNMaterial()
        material.diffuse.contents = gradient
        material.lightingModel = .constant
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        material.isDoubleSided = true
        plane.materials = [material]

        atmosphereNode.geometry = plane
        atmosphereNode.constraints = [SCNBillboardConstraint()]
        atmosphereNode.renderingOrder = 30
        scene.rootNode.addChildNode(atmosphereNode)
    }

    private func buildLights() {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1150
        sun.color = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.94, alpha: 1.0)
        sunLightNode.light = sun
        // A directional light is defined by orientation only; it is
        // parented to the scene root (not the globe) so the sun stays
        // fixed in world space while the globe turns under it.
        scene.rootNode.addChildNode(sunLightNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        // Low enough for a real night side, high enough that the night
        // hemisphere still shows its coastlines rather than a void.
        ambient.intensity = 180
        ambient.color = NSColor(calibratedRed: 0.42, green: 0.52, blue: 0.72, alpha: 1.0)
        ambientLightNode.light = ambient
        scene.rootNode.addChildNode(ambientLightNode)
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 0.05
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, Float(CameraState.defaultDistance))
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Data

    /// Installs a loaded dataset: builds the land texture and the
    /// one-draw-call border geometry.
    ///
    /// Rasterization is the expensive part and is done by the caller off
    /// the main actor (see `GlobeResources`); this method only uploads
    /// the results and builds geometry.
    public func install(resources: GlobeResources) {
        dataset = resources.dataset
        indexMap = resources.indexMap

        // Only fall back to the generated land/ocean texture when the
        // photographic imagery is missing; otherwise the imagery stays.
        if !hasSurfaceImagery {
            if let texture = resources.baseTexture {
                surfaceNode.geometry?.firstMaterial?.diffuse.contents = texture
                Self.logger.notice("Surface imagery unavailable; using the generated land texture")
            } else {
                Self.logger.error("Neither surface imagery nor a generated land texture is available")
            }
        }

        borderNode.geometry = BorderGeometry.outlineGeometry(
            for: resources.dataset.countries,
            radius: GlobeTheme.borderRadius,
            color: theme.border
        )

        labelNodes.removeAll()
        labelRootNode.childNodes.forEach { $0.removeFromParentNode() }
        for country in resources.dataset.countries {
            guard let node = GlobeLabelFactory.labelNode(for: country, theme: theme) else { continue }
            labelNodes[country.id] = node
            labelRootNode.addChildNode(node)
        }

        Self.logger.info("Installed globe resources for \(resources.dataset.countries.count, privacy: .public) countries")
    }

    // MARK: - State application

    public func apply(camera: CameraState) {
        let angles = camera.modelEulerAngles
        globeNode.eulerAngles = SCNVector3(Float(angles.x), Float(angles.y), Float(angles.z))
        cameraNode.position = SCNVector3(0, 0, Float(camera.distance))
    }

    /// Updates the highlight: a tinted overlay, a brighter outline, and
    /// a ring marker at the country's anchor.
    ///
    /// Three cues, only one of which is colour — FR-11 requires that
    /// selection not be conveyed by colour alone, and the ring plus the
    /// facts panel carry it for anyone who cannot distinguish the tint.
    public func apply(selection: Country?, overlay: CGImage?) {
        selectedID = selection?.id

        if let overlay {
            selectionNode.geometry?.firstMaterial?.diffuse.contents = overlay
            selectionNode.isHidden = false
        } else {
            selectionNode.isHidden = true
        }

        if let selection {
            selectedBorderNode.geometry = BorderGeometry.outlineGeometry(
                for: [selection],
                radius: GlobeTheme.borderRadius + 0.0012,
                color: theme.selectionBorder
            )
            selectionMarkerNode.geometry = selectionMarkerGeometry()
            let point = SphereProjection.point(for: selection.labelAnchor, radius: GlobeTheme.markerRadius)
            selectionMarkerNode.position = SCNVector3(Float(point.x), Float(point.y), Float(point.z))
            selectionMarkerNode.constraints = [SCNBillboardConstraint()]
            selectionMarkerNode.isHidden = false
        } else {
            selectedBorderNode.geometry = nil
            selectionMarkerNode.isHidden = true
        }
    }

    private func selectionMarkerGeometry() -> SCNGeometry? {
        // An open ring, drawn as line segments so it never fills over
        // the country's own borders.
        let segments = 48
        let radius = 0.045
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        for step in 0...segments {
            let angle = Double(step) / Double(segments) * 2 * .pi
            vertices.append(SCNVector3(Float(cos(angle) * radius), Float(sin(angle) * radius), 0))
        }
        for step in 0..<segments {
            indices.append(Int32(step))
            indices.append(Int32(step + 1))
        }
        return BorderGeometry.geometry(vertices: vertices, indices: indices, color: theme.selectionBorder)
    }

    /// Positions the sun light.
    ///
    /// With day/night on, the light points along the real subsolar
    /// direction, so the terminator is where the lambertian falloff
    /// lands — no separate terminator geometry exists. With it off, the
    /// light sits behind the camera so the whole visible disc is evenly
    /// lit.
    public func apply(dayNightEnabled: Bool, date: Date) {
        if dayNightEnabled {
            let direction = SolarPosition.directionInModelSpace(at: date)
            sunLightNode.position = SCNVector3(
                Float(direction.x * 10),
                Float(direction.y * 10),
                Float(direction.z * 10)
            )
            sunLightNode.look(
                at: SCNVector3Zero,
                up: SCNVector3(0, 1, 0),
                localFront: SCNVector3(0, 0, -1)
            )
            ambientLightNode.light?.intensity = 180
        } else {
            sunLightNode.position = SCNVector3(0, 0, 10)
            sunLightNode.look(
                at: SCNVector3Zero,
                up: SCNVector3(0, 1, 0),
                localFront: SCNVector3(0, 0, -1)
            )
            ambientLightNode.light?.intensity = 520
        }
    }

    public func setLabelsEnabled(_ enabled: Bool) {
        guard labelsEnabled != enabled else { return }
        labelsEnabled = enabled
        if !enabled {
            for id in visibleLabelIDs { labelNodes[id]?.isHidden = true }
            visibleLabelIDs.removeAll()
        }
        // Force the next layout pass to run even if the camera has not
        // moved, so labels come back immediately when re-enabled.
        lastLabelLayoutCamera = nil
    }

    // MARK: - Labels

    /// Recomputes which labels are drawn.
    ///
    /// Skipped when the camera has barely moved, so a static globe does
    /// no label work at all and a slow rotation does it a few times a
    /// second rather than every frame.
    public func updateLabels(camera: CameraState, viewportSize: CGSize, force: Bool = false) {
        guard labelsEnabled, let dataset else { return }
        guard viewportSize.width > 1, viewportSize.height > 1 else { return }

        if !force, let last = lastLabelLayoutCamera, !hasMovedEnoughForRelayout(from: last, to: camera) {
            return
        }
        lastLabelLayoutCamera = camera

        let pointsPerRadius = pointsPerGlobeRadius(viewportSize: viewportSize, distance: camera.distance)
        let cameraPosition = camera.cameraPosition
        var candidates: [LabelCandidate] = []
        candidates.reserveCapacity(dataset.countries.count)

        for country in dataset.countries {
            let modelPoint = SphereProjection.point(for: country.labelAnchor)
            let worldPoint = camera.worldPoint(forModel: modelPoint)

            // Front-facing test: the surface normal at the anchor must
            // point toward the camera. Equivalent to the dot-product
            // horizon test, and it uses the same transform the geometry
            // was built with.
            let toCamera = cameraPosition - worldPoint
            let isFrontFacing = SphereProjection.dot(worldPoint, toCamera) > 0

            guard let screenPoint = projectToView(
                worldPoint: worldPoint,
                viewportSize: viewportSize,
                distance: camera.distance
            ) else { continue }

            candidates.append(
                LabelCandidate(
                    id: country.id,
                    screenPoint: screenPoint,
                    size: GlobeLabelFactory.labelSizeInPoints(for: country, pointsPerRadius: pointsPerRadius),
                    priority: country.geometry.relativeSize,
                    isFrontFacing: isFrontFacing
                )
            )
        }

        let visible = Set(
            LabelLayoutEngine.visibleLabels(
                candidates: candidates,
                viewportSize: viewportSize,
                minimumPriority: LabelLayoutEngine.minimumPriority(forDistance: camera.distance),
                alwaysInclude: selectedID
            )
        )

        for id in visibleLabelIDs.subtracting(visible) {
            labelNodes[id]?.isHidden = true
        }
        for id in visible.subtracting(visibleLabelIDs) {
            labelNodes[id]?.isHidden = false
        }
        visibleLabelIDs = visible
    }

    private func hasMovedEnoughForRelayout(from old: CameraState, to new: CameraState) -> Bool {
        let yawDelta = abs(CameraState.normalizedYaw(new.yawDegrees - old.yawDegrees))
        return yawDelta > 1.0
            || abs(new.pitchDegrees - old.pitchDegrees) > 1.0
            || abs(new.distance - old.distance) > 0.01
    }

    /// View points covered by one globe radius at `distance`, from the
    /// camera's vertical field of view.
    func pointsPerGlobeRadius(viewportSize: CGSize, distance: Double) -> CGFloat {
        let fieldOfView = (cameraNode.camera?.fieldOfView ?? 40) * .pi / 180
        let halfHeightAtGlobe = tan(fieldOfView / 2) * distance
        guard halfHeightAtGlobe > 0 else { return 0 }
        return CGFloat(Double(viewportSize.height) / 2 / halfHeightAtGlobe)
    }

    /// Projects a world point to view coordinates, by hand rather than
    /// through `SCNView.projectPoint`, so the label pass does not depend
    /// on a live view and can be exercised in tests.
    func projectToView(worldPoint: SIMD3<Double>, viewportSize: CGSize, distance: Double) -> CGPoint? {
        // Camera looks down -Z from +distance, so depth is distance - z.
        let depth = distance - worldPoint.z
        guard depth > 0.001 else { return nil }

        let fieldOfView = (cameraNode.camera?.fieldOfView ?? 40) * .pi / 180
        let halfHeight = tan(fieldOfView / 2) * depth
        guard halfHeight > 0 else { return nil }

        let normalizedY = worldPoint.y / halfHeight
        let aspect = Double(viewportSize.width / max(viewportSize.height, 1))
        let normalizedX = worldPoint.x / (halfHeight * aspect)

        return CGPoint(
            x: (normalizedX + 1) / 2 * Double(viewportSize.width),
            y: (normalizedY + 1) / 2 * Double(viewportSize.height)
        )
    }
}

/// Everything expensive that has to be prepared before the globe can be
/// drawn, built off the main actor in one place.
public struct GlobeResources: Sendable {
    public let dataset: GeographyDataset
    public let indexMap: CountryIndexMap
    public let baseTexture: CGImage?

    /// Rasterizes the dataset and builds the land texture.
    ///
    /// Called from a detached task: this is the one genuinely costly
    /// step at startup (a few million pixel writes), and it must not run
    /// on the main actor.
    public static func prepare(dataset: GeographyDataset, theme: GlobeTheme = .standard) -> GlobeResources {
        let map = EquirectangularRasterizer.rasterize(countries: dataset.countries)
        return GlobeResources(
            dataset: dataset,
            indexMap: map,
            baseTexture: GlobeTextureFactory.baseTexture(from: map, theme: theme)
        )
    }
}

extension GlobeSceneController {
    /// The coordinate under a point in the view, or `nil` when the
    /// point misses the globe.
    ///
    /// The exact inverse of `projectToView`, feeding
    /// `SphereProjection.intersectSphere` and then the camera's inverse
    /// model rotation. Selection therefore travels through the same
    /// transform chain the geometry was built with — the single
    /// projection requirement in docs/ARCHITECTURE.md — rather than
    /// through `SCNView.hitTest`, which would answer against the
    /// tessellated sphere instead of the geographic surface.
    public func coordinate(
        atViewPoint point: CGPoint,
        viewportSize: CGSize,
        camera: CameraState
    ) -> Coordinate? {
        guard viewportSize.width > 1, viewportSize.height > 1 else { return nil }

        let fieldOfView = (cameraNode.camera?.fieldOfView ?? 40) * .pi / 180
        let tangent = tan(fieldOfView / 2)
        let aspect = Double(viewportSize.width / max(viewportSize.height, 1))

        let normalizedX = Double(point.x) / Double(viewportSize.width) * 2 - 1
        let normalizedY = Double(point.y) / Double(viewportSize.height) * 2 - 1

        let direction = SIMD3<Double>(
            normalizedX * tangent * aspect,
            normalizedY * tangent,
            -1
        )

        guard let hit = SphereProjection.intersectSphere(
            rayOrigin: camera.cameraPosition,
            rayDirection: direction,
            radius: GlobeTheme.surfaceRadius
        ) else { return nil }

        return SphereProjection.coordinate(for: camera.modelPoint(forWorld: hit))
    }
}
