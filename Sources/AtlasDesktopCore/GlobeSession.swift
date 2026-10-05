import Foundation
import Observation
import os

/// The app's product state: what is loaded, where the camera points,
/// what is selected, and which preferences are in force.
///
/// It owns no GPU resources and parses no datasets — the renderer reads
/// from it and the repository feeds it — which is what keeps the globe
/// logic testable without a window on screen.
@MainActor
@Observable
public final class GlobeSession {
    public enum LoadState: Equatable {
        case loading
        case ready
        case failed(GeographyError)
    }

    private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "session")

    // MARK: - Dependencies

    private let repository: GeographyRepository
    private let preferencesStore: PreferencesStore
    /// Supplied by the app from `NSWorkspace`; a closure so tests can
    /// drive the reduced-motion path without touching system settings.
    private let reducedMotionProvider: @MainActor () -> Bool

    // MARK: - Observable state

    public private(set) var loadState: LoadState = .loading
    public private(set) var dataset: GeographyDataset?
    public private(set) var selectedCountry: Country?
    /// In learning mode, facts stay hidden until the user asks for
    /// them. Outside learning mode this is always true.
    public private(set) var isAnswerRevealed: Bool = true
    public private(set) var camera: CameraState = .home
    public private(set) var preferences: Preferences
    /// True while the pointer is mid-drag, so auto-rotation can yield
    /// to direct manipulation and resume afterwards.
    public private(set) var isInteracting: Bool = false

    public init(
        repository: GeographyRepository,
        preferencesStore: PreferencesStore,
        reducedMotionProvider: @escaping @MainActor () -> Bool = { false }
    ) {
        self.repository = repository
        self.preferencesStore = preferencesStore
        self.reducedMotionProvider = reducedMotionProvider
        let loaded = preferencesStore.load()
        self.preferences = loaded
        if loaded.restoresCameraOnLaunch, let stored = loaded.camera {
            self.camera = stored
        }
    }

    // MARK: - Derived state

    /// Whether the globe should actually be rotating right now.
    ///
    /// The preference is only one input: a user drag takes precedence
    /// while it lasts, and the system reduce-motion setting suppresses
    /// rotation entirely when the user has asked it to (FR-05).
    public var isAutoRotating: Bool {
        guard preferences.autoRotationEnabled else { return false }
        if isInteracting { return false }
        if preferences.respectsReducedMotion, reducedMotionProvider() { return false }
        return true
    }

    /// True when rotation is switched on but the system's reduce-motion
    /// setting is holding it back — the UI says so rather than leaving
    /// a toggle that looks on while nothing moves.
    public var isAutoRotationSuppressedByReducedMotion: Bool {
        preferences.autoRotationEnabled
            && preferences.respectsReducedMotion
            && reducedMotionProvider()
    }

    /// Labels are hidden in learning mode, and can also be turned off
    /// outright in settings.
    public var areLabelsVisible: Bool {
        preferences.labelsEnabled && !preferences.learningModeEnabled
    }

    /// Whether the facts panel should show the selected country's
    /// facts, as opposed to the "reveal" prompt.
    public var areFactsVisible: Bool {
        !preferences.learningModeEnabled || isAnswerRevealed
    }

    public var isLearningModeEnabled: Bool { preferences.learningModeEnabled }
    public var isDayNightEnabled: Bool { preferences.dayNightEnabled }
    public var autoRotationDegreesPerSecond: Double { preferences.autoRotationDegreesPerSecond }

    public var loadError: GeographyError? {
        if case .failed(let error) = loadState { return error }
        return nil
    }

    // MARK: - Loading

    public func load() async {
        loadState = .loading
        do {
            let dataset = try await repository.load()
            self.dataset = dataset
            self.loadState = .ready
            Self.logger.info("Loaded \(dataset.countries.count, privacy: .public) countries")
        } catch let error as GeographyError {
            self.loadState = .failed(error)
            // A failure here disables the app's core feature, so it is
            // logged at error level and surfaced in the UI, never
            // swallowed (FR-12).
            Self.logger.error("Geography load failed: \(error.localizedDescription, privacy: .public)")
        } catch {
            let wrapped = GeographyError.malformedData(reason: error.localizedDescription)
            self.loadState = .failed(wrapped)
            Self.logger.error("Geography load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Selection

    /// Selects whatever country lies under `coordinate`.
    ///
    /// Clicking open ocean clears the selection: the documented
    /// behaviour for FR-03's "clicking empty space".
    @discardableResult
    public func selectCountry(at coordinate: Coordinate) -> Country? {
        let hit = dataset?.lookup.country(at: coordinate)
        select(hit)
        return hit
    }

    public func select(id: CountryID) {
        select(dataset?.lookup.country(id: id))
    }

    public func select(_ country: Country?) {
        selectedCountry = country
        // In learning mode a fresh selection starts hidden, so the user
        // can recall the country before revealing it.
        isAnswerRevealed = !(preferences.learningModeEnabled && country != nil)
    }

    public func clearSelection() {
        selectedCountry = nil
        isAnswerRevealed = true
    }

    public func revealAnswer() {
        isAnswerRevealed = true
    }

    public func hideAnswer() {
        guard preferences.learningModeEnabled else { return }
        isAnswerRevealed = false
    }

    // MARK: - Camera

    public func beginInteraction() { isInteracting = true }

    public func endInteraction() {
        isInteracting = false
        persistCameraIfNeeded()
    }

    public func drag(deltaX: Double, deltaY: Double, degreesPerPoint: Double) {
        camera.applyDrag(deltaX: deltaX, deltaY: deltaY, degreesPerPoint: degreesPerPoint)
    }

    public func zoom(factor: Double) {
        camera.applyZoom(factor: factor)
        persistCameraIfNeeded()
    }

    /// One keyboard/button zoom step. 1.2× per press, matching roughly
    /// one scroll notch.
    public func zoomIn() { zoom(factor: 1 / 1.2) }
    public func zoomOut() { zoom(factor: 1.2) }

    public func advanceAutoRotation(elapsed: TimeInterval) {
        guard isAutoRotating else { return }
        camera.advanceAutoRotation(
            degreesPerSecond: preferences.autoRotationDegreesPerSecond,
            elapsed: elapsed
        )
    }

    public func resetView() {
        camera = .home
        persistCameraIfNeeded()
    }

    /// Points the camera at a country without changing the zoom level,
    /// so selecting from the keyboard-accessible list brings it into
    /// view (FR-11).
    public func focus(on country: Country) {
        camera.yawDegrees = CameraState.normalizedYaw(country.labelAnchor.longitude)
        camera.pitchDegrees = CameraState.clampPitch(country.labelAnchor.latitude)
        persistCameraIfNeeded()
    }

    // MARK: - Preferences

    public func setAutoRotation(enabled: Bool) {
        update { $0.autoRotationEnabled = enabled }
    }

    public func toggleAutoRotation() {
        setAutoRotation(enabled: !preferences.autoRotationEnabled)
    }

    public func setAutoRotationSpeed(_ degreesPerSecond: Double) {
        update { $0.autoRotationDegreesPerSecond = degreesPerSecond }
    }

    public func setLearningMode(enabled: Bool) {
        update { $0.learningModeEnabled = enabled }
        // Leaving learning mode must not leave facts hidden; entering it
        // must not leave the previous answer on screen.
        isAnswerRevealed = !(enabled && selectedCountry != nil)
    }

    public func toggleLearningMode() {
        setLearningMode(enabled: !preferences.learningModeEnabled)
    }

    public func setLabels(enabled: Bool) {
        update { $0.labelsEnabled = enabled }
    }

    public func setDayNight(enabled: Bool) {
        update { $0.dayNightEnabled = enabled }
    }

    public func setRespectsReducedMotion(_ value: Bool) {
        update { $0.respectsReducedMotion = value }
    }

    public func setRestoresCameraOnLaunch(_ value: Bool) {
        update {
            $0.restoresCameraOnLaunch = value
            $0.camera = value ? self.camera : nil
        }
    }

    private func update(_ mutate: (inout Preferences) -> Void) {
        var updated = preferences
        mutate(&updated)
        preferences = updated.sanitized()
        persist()
    }

    private func persistCameraIfNeeded() {
        guard preferences.restoresCameraOnLaunch else { return }
        preferences.camera = camera
        persist()
    }

    private func persist() {
        preferencesStore.save(preferences)
    }
}
