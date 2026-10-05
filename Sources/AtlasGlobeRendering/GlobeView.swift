import SwiftUI
import SceneKit
import AtlasDesktopCore
import os

/// SwiftUI wrapper around the globe.
///
/// The one place renderer and product state meet: SwiftUI invalidates
/// this view when the observable session changes, `updateNSView` pushes
/// the new state into the scene, and the coordinator feeds input back
/// into the session. No globe state is duplicated here — the session
/// remains the single source of truth.
public struct GlobeView: NSViewRepresentable {
    private let session: GlobeSession
    private let theme: GlobeTheme

    public init(session: GlobeSession, theme: GlobeTheme = .standard) {
        self.session = session
        self.theme = theme
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(session: session, theme: theme)
    }

    public func makeNSView(context: Context) -> GlobeInteractionView {
        let view = GlobeInteractionView(frame: .zero)
        view.scene = context.coordinator.controller.scene
        view.pointOfView = context.coordinator.controller.cameraNode
        view.backgroundColor = theme.space
        view.interactionDelegate = context.coordinator
        view.coordinateResolver = { [weak coordinator = context.coordinator] point, size in
            guard let coordinator else { return nil }
            return coordinator.controller.coordinate(
                atViewPoint: point,
                viewportSize: size,
                camera: coordinator.session.camera
            )
        }
        context.coordinator.view = view
        context.coordinator.startLoadingResourcesIfNeeded()
        return view
    }

    public func updateNSView(_ view: GlobeInteractionView, context: Context) {
        context.coordinator.apply(to: view)
    }

    @MainActor
    public final class Coordinator: GlobeInteractionDelegate {
        private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "globe")

        let session: GlobeSession
        let controller: GlobeSceneController
        weak var view: GlobeInteractionView?

        private var resources: GlobeResources?
        private var isPreparingResources = false
        private var appliedSelection: CountryID??
        private var appliedLabelsVisible: Bool?
        private var appliedDayNight: Bool?
        private var lastSunUpdate: Date?

        init(session: GlobeSession, theme: GlobeTheme) {
            self.session = session
            self.controller = GlobeSceneController(theme: theme)
            controller.apply(camera: session.camera)
            controller.apply(dayNightEnabled: session.isDayNightEnabled, date: Date())
        }

        /// Rasterizes and uploads the dataset once it has loaded.
        ///
        /// Runs in a detached task: it is the only startup step heavy
        /// enough to be worth moving off the main actor, and doing so is
        /// what keeps the window responsive while the globe appears.
        func startLoadingResourcesIfNeeded() {
            guard resources == nil, !isPreparingResources, let dataset = session.dataset else { return }
            isPreparingResources = true

            Task { [weak self] in
                let prepared = await Task.detached(priority: .userInitiated) {
                    GlobeResources.prepare(dataset: dataset)
                }.value

                guard let self else { return }
                self.resources = prepared
                self.isPreparingResources = false
                self.controller.install(resources: prepared)
                if let view = self.view {
                    self.apply(to: view)
                    view.requestTransientRender(frames: 8)
                }
                Self.logger.info("Globe resources ready")
            }
        }

        func apply(to view: GlobeInteractionView) {
            startLoadingResourcesIfNeeded()

            controller.apply(camera: session.camera)

            if appliedDayNight != session.isDayNightEnabled {
                appliedDayNight = session.isDayNightEnabled
                controller.apply(dayNightEnabled: session.isDayNightEnabled, date: Date())
                lastSunUpdate = Date()
            }

            if appliedLabelsVisible != session.areLabelsVisible {
                appliedLabelsVisible = session.areLabelsVisible
                controller.setLabelsEnabled(session.areLabelsVisible)
            }

            let currentSelection = session.selectedCountry?.id
            if appliedSelection != .some(currentSelection) {
                appliedSelection = .some(currentSelection)
                applySelection(session.selectedCountry, to: view)
            }

            controller.updateLabels(camera: session.camera, viewportSize: view.bounds.size)
            updateAccessibility(view)

            view.setContinuousAnimation(session.isAutoRotating)
            view.requestTransientRender()
        }

        private func applySelection(_ country: Country?, to view: GlobeInteractionView) {
            guard let resources else {
                controller.apply(selection: country, overlay: nil)
                return
            }
            guard let country else {
                controller.apply(selection: nil, overlay: nil)
                view.requestTransientRender()
                return
            }

            // Show the outline and marker immediately; the tinted
            // overlay is a full-texture pass, so it is built off the
            // main actor and applied when ready. Selection therefore
            // never costs a dropped frame.
            controller.apply(selection: country, overlay: nil)
            let map = resources.indexMap
            let theme = controller.theme
            let id = country.id

            Task { [weak self, weak view] in
                let overlay = await Task.detached(priority: .userInitiated) {
                    UncheckedImage(GlobeTextureFactory.selectionOverlay(from: map, selected: id, theme: theme))
                }.value

                guard let self, self.session.selectedCountry?.id == id else { return }
                self.controller.apply(selection: country, overlay: overlay.image)
                view?.requestTransientRender()
            }
        }

        private func updateAccessibility(_ view: GlobeInteractionView) {
            let orientation: String
            if let centre = session.camera.centerCoordinate {
                orientation = String(
                    format: "Centred on %.0f° %@, %.0f° %@",
                    abs(centre.latitude), centre.latitude >= 0 ? "north" : "south",
                    abs(centre.longitude), centre.longitude >= 0 ? "east" : "west"
                )
            } else {
                orientation = "Centred on the equator"
            }

            let selection: String
            if let country = session.selectedCountry {
                selection = session.areFactsVisible
                    ? "\(country.facts.name) selected."
                    : "A country is selected; its name is hidden in learning mode."
            } else {
                selection = "No country selected."
            }

            view.setAccessibilityValue("\(selection) \(orientation).")
        }

        // MARK: - GlobeInteractionDelegate

        public func globeViewDidBeginInteraction() {
            session.beginInteraction()
        }

        public func globeViewDidEndInteraction() {
            session.endInteraction()
            view?.setContinuousAnimation(session.isAutoRotating)
        }

        public func globeView(didDragBy deltaX: Double, deltaY: Double, degreesPerPoint: Double) {
            session.drag(deltaX: deltaX, deltaY: deltaY, degreesPerPoint: degreesPerPoint)
            controller.apply(camera: session.camera)
            if let view { controller.updateLabels(camera: session.camera, viewportSize: view.bounds.size) }
        }

        public func globeView(didZoomBy factor: Double) {
            session.zoom(factor: factor)
            controller.apply(camera: session.camera)
            if let view { controller.updateLabels(camera: session.camera, viewportSize: view.bounds.size) }
        }

        public func globeView(didClickAt coordinate: Coordinate?) {
            guard let coordinate else {
                session.clearSelection()
                return
            }
            session.selectCountry(at: coordinate)
        }

        public func globeViewDidTick(elapsed: TimeInterval) {
            if session.isAutoRotating, elapsed > 0 {
                session.advanceAutoRotation(elapsed: elapsed)
                controller.apply(camera: session.camera)
            }

            guard let view else { return }
            controller.updateLabels(camera: session.camera, viewportSize: view.bounds.size)

            // The sun moves 0.25° per minute; refreshing the light every
            // 10 seconds is imperceptible and costs nothing.
            let now = Date()
            if session.isDayNightEnabled, lastSunUpdate == nil || now.timeIntervalSince(lastSunUpdate!) > 10 {
                lastSunUpdate = now
                controller.apply(dayNightEnabled: true, date: now)
            }
        }
    }
}

/// `CGImage` is immutable and safe to hand between tasks, but is not
/// annotated `Sendable`. This wrapper keeps that assertion in one
/// documented place instead of scattering `@unchecked` across the
/// renderer.
struct UncheckedImage: @unchecked Sendable {
    let image: CGImage?
    init(_ image: CGImage?) { self.image = image }
}
