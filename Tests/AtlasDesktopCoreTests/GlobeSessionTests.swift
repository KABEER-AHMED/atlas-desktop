import Foundation
import Testing
@testable import AtlasDesktopCore

/// Fixtures for session tests: two squares, one large and one small and
/// fully inside the large one, which is enough to exercise selection,
/// the smaller-country-wins rule, and open ocean.
enum Fixtures {
    static func ring(_ points: [(Double, Double)]) throws -> GeoRing {
        try GeoRing(coordinates: points.map { try Coordinate(latitude: $0.0, longitude: $0.1) })
    }

    static func country(
        id: String,
        name: String,
        capitals: [String] = [],
        isoAlpha3: String? = nil,
        corners: [(Double, Double)],
        anchor: (Double, Double)
    ) throws -> Country {
        Country(
            facts: CountryFacts(
                id: CountryID(rawValue: id)!,
                name: name,
                isoAlpha3: isoAlpha3,
                continent: "Testland",
                capitals: capitals
            ),
            geometry: try CountryGeometry(polygons: [GeoPolygon(outerRing: try ring(corners))]),
            labelAnchor: try Coordinate(latitude: anchor.0, longitude: anchor.1)
        )
    }

    static func dataset() throws -> GeographyDataset {
        GeographyDataset(
            countries: [
                try country(
                    id: "BIG", name: "Bigland", capitals: ["Bigton"], isoAlpha3: "BIG",
                    corners: [(0, 0), (0, 40), (40, 40), (40, 0)], anchor: (20, 20)
                ),
                try country(
                    id: "SML", name: "Smallia",
                    corners: [(18, 18), (18, 22), (22, 22), (22, 18)], anchor: (20, 20)
                )
            ],
            provenance: provenance
        )
    }

    static let provenance = DatasetProvenance(
        geometrySource: "fixture", geometrySourceURL: "", geometryVersion: "1",
        geometryLicense: "n/a", metadataSource: "fixture", metadataSourceURL: "",
        metadataVersion: "1", metadataLicense: "n/a",
        imagerySource: "fixture", imagerySourceURL: "", imageryLicense: "n/a",
        imageryAttribution: "", attribution: "fixture data",
        transformations: [], generatedAt: "test", countryCount: 2
    )
}

@MainActor
struct GlobeSessionTests {
    private func makeSession(
        dataset: GeographyDataset? = nil,
        failure: GeographyError? = nil,
        store: PreferencesStore = InMemoryPreferencesStore(),
        reduceMotion: Bool = false
    ) throws -> GlobeSession {
        let repository: GeographyRepository
        if let failure {
            repository = StaticGeographyRepository(failure: failure)
        } else {
            repository = StaticGeographyRepository(dataset: try dataset ?? Fixtures.dataset())
        }
        return GlobeSession(
            repository: repository,
            preferencesStore: store,
            reducedMotionProvider: { reduceMotion }
        )
    }

    @Test func loadsTheDataset() async throws {
        let session = try makeSession()
        await session.load()
        #expect(session.loadState == .ready)
        #expect(session.dataset?.countries.count == 2)
    }

    /// A load failure must surface, not disappear: the UI shows the
    /// error rather than an unexplained blank globe.
    @Test func loadFailureIsSurfaced() async throws {
        let session = try makeSession(failure: .resourceMissing(name: "atlas-countries.json"))
        await session.load()
        #expect(session.loadState == .failed(.resourceMissing(name: "atlas-countries.json")))
        #expect(session.loadError?.recoverySuggestion != nil)
    }

    @Test func selectingACoordinatePicksTheCountryUnderIt() async throws {
        let session = try makeSession()
        await session.load()

        session.selectCountry(at: try Coordinate(latitude: 5, longitude: 5))
        #expect(session.selectedCountry?.facts.name == "Bigland")
    }

    /// Where two countries overlap, the smaller one wins — otherwise an
    /// enclave could never be selected.
    @Test func smallerCountryWinsWhereGeometriesOverlap() async throws {
        let session = try makeSession()
        await session.load()

        session.selectCountry(at: try Coordinate(latitude: 20, longitude: 20))
        #expect(session.selectedCountry?.facts.name == "Smallia")
    }

    @Test func clickingOpenOceanClearsTheSelection() async throws {
        let session = try makeSession()
        await session.load()

        session.selectCountry(at: try Coordinate(latitude: 5, longitude: 5))
        session.selectCountry(at: try Coordinate(latitude: -50, longitude: -50))
        #expect(session.selectedCountry == nil)
    }

    // MARK: - Learning mode

    @Test func learningModeHidesLabelsButKeepsSelectionWorking() async throws {
        let session = try makeSession()
        await session.load()
        session.setLearningMode(enabled: true)

        #expect(!session.areLabelsVisible)

        session.selectCountry(at: try Coordinate(latitude: 5, longitude: 5))
        #expect(session.selectedCountry != nil)
        // Selecting reveals nothing until asked.
        #expect(!session.areFactsVisible)

        session.revealAnswer()
        #expect(session.areFactsVisible)

        session.hideAnswer()
        #expect(!session.areFactsVisible)
    }

    @Test func leavingLearningModeShowsTheFactsAgain() async throws {
        let session = try makeSession()
        await session.load()
        session.setLearningMode(enabled: true)
        session.selectCountry(at: try Coordinate(latitude: 5, longitude: 5))
        #expect(!session.areFactsVisible)

        session.setLearningMode(enabled: false)
        #expect(session.areFactsVisible)
        #expect(session.areLabelsVisible)
    }

    @Test func hidingTheAnswerOutsideLearningModeDoesNothing() async throws {
        let session = try makeSession()
        await session.load()
        session.selectCountry(at: try Coordinate(latitude: 5, longitude: 5))
        session.hideAnswer()
        #expect(session.areFactsVisible)
    }

    // MARK: - Motion

    @Test func autoRotationFollowsThePreference() async throws {
        let session = try makeSession()
        #expect(session.isAutoRotating)

        session.toggleAutoRotation()
        #expect(!session.isAutoRotating)

        session.advanceAutoRotation(elapsed: 1)
        #expect(session.camera.yawDegrees == 0)
    }

    /// A drag takes precedence over auto-rotation while it lasts, and
    /// rotation resumes when the drag ends.
    @Test func directInteractionPausesAutoRotation() async throws {
        let session = try makeSession()
        session.beginInteraction()
        #expect(!session.isAutoRotating)

        session.advanceAutoRotation(elapsed: 1)
        #expect(session.camera.yawDegrees == 0)

        session.endInteraction()
        #expect(session.isAutoRotating)
    }

    @Test func reduceMotionSuppressesRotationAndIsReported() async throws {
        let session = try makeSession(reduceMotion: true)
        #expect(!session.isAutoRotating)
        #expect(session.isAutoRotationSuppressedByReducedMotion)

        session.setRespectsReducedMotion(false)
        #expect(session.isAutoRotating)
        #expect(!session.isAutoRotationSuppressedByReducedMotion)
    }

    @Test func resetReturnsToTheHomeView() async throws {
        let session = try makeSession()
        session.drag(deltaX: 120, deltaY: 40, degreesPerPoint: 0.3)
        session.zoom(factor: 0.5)
        #expect(session.camera != .home)

        session.resetView()
        #expect(session.camera == .home)
    }

    @Test func focusPointsTheCameraAtACountryWithoutChangingZoom() async throws {
        let session = try makeSession()
        await session.load()
        session.zoom(factor: 0.8)
        let distance = session.camera.distance

        let country = try #require(session.dataset?.countries.first)
        session.focus(on: country)
        #expect(abs(session.camera.yawDegrees - country.labelAnchor.longitude) < 1e-9)
        #expect(abs(session.camera.pitchDegrees - country.labelAnchor.latitude) < 1e-9)
        #expect(session.camera.distance == distance)
    }

    // MARK: - Preferences

    @Test func preferenceChangesArePersistedImmediately() async throws {
        let store = InMemoryPreferencesStore()
        let session = try makeSession(store: store)

        session.setLearningMode(enabled: true)
        session.setAutoRotationSpeed(9)
        #expect(store.load().learningModeEnabled)
        #expect(store.load().autoRotationDegreesPerSecond == 9)
    }

    @Test func invalidSpeedIsClampedBeforeItIsStored() async throws {
        let store = InMemoryPreferencesStore()
        let session = try makeSession(store: store)
        session.setAutoRotationSpeed(10_000)
        #expect(session.autoRotationDegreesPerSecond == Preferences.maxRotationSpeed)
        #expect(store.load().autoRotationDegreesPerSecond == Preferences.maxRotationSpeed)
    }

    @Test func cameraIsRestoredOnlyWhenThePreferenceIsOn() async throws {
        let store = InMemoryPreferencesStore()
        let first = try makeSession(store: store)
        first.drag(deltaX: -100, deltaY: 0, degreesPerPoint: 0.3)
        first.endInteraction()
        let saved = first.camera

        let restored = try makeSession(store: store)
        #expect(restored.camera == saved)

        restored.setRestoresCameraOnLaunch(false)
        let fresh = try makeSession(store: store)
        #expect(fresh.camera == .home)
    }
}
