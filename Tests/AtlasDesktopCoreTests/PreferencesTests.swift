import Foundation
import Testing
@testable import AtlasDesktopCore

struct PreferencesTests {
    @Test func defaultsAreUsable() {
        let defaults = Preferences.default
        #expect(defaults.autoRotationEnabled)
        #expect(defaults.respectsReducedMotion)
        #expect(defaults.labelsEnabled)
        #expect(!defaults.learningModeEnabled)
        #expect(defaults.version == Preferences.currentVersion)
    }

    @Test func roundTripsThroughJSON() throws {
        var preferences = Preferences.default
        preferences.learningModeEnabled = true
        preferences.autoRotationDegreesPerSecond = 7.5
        preferences.camera = CameraState(yawDegrees: 12, pitchDegrees: 34, distance: 2)

        let decoded = try JSONDecoder().decode(
            Preferences.self,
            from: try JSONEncoder().encode(preferences)
        )
        #expect(decoded == preferences)
    }

    /// A hand-edited or stale defaults file must not be able to produce
    /// a stuck globe or a camera inside the sphere.
    @Test func sanitizingClampsOutOfRangeValues() {
        var preferences = Preferences.default
        preferences.autoRotationDegreesPerSecond = 9000
        #expect(preferences.sanitized().autoRotationDegreesPerSecond == Preferences.maxRotationSpeed)

        preferences.autoRotationDegreesPerSecond = -4
        #expect(preferences.sanitized().autoRotationDegreesPerSecond == Preferences.minRotationSpeed)

        preferences.autoRotationDegreesPerSecond = .nan
        #expect(preferences.sanitized().autoRotationDegreesPerSecond == Preferences.defaultRotationSpeed)
    }

    @Test func sanitizingReappliesTheCameraBounds() throws {
        var preferences = Preferences.default
        // A camera decoded from an older or edited file can hold values
        // the current bounds forbid.
        var camera = CameraState.home
        let json = """
        {"yawDegrees":400,"pitchDegrees":120,"distance":0.2}
        """
        camera = try JSONDecoder().decode(CameraState.self, from: Data(json.utf8))
        preferences.camera = camera

        let sanitized = try #require(preferences.sanitized().camera)
        #expect(sanitized.pitchDegrees == CameraState.maxPitch)
        #expect(sanitized.distance == CameraState.minDistance)
        #expect(sanitized.yawDegrees == 40)
    }

    /// A payload from a future build is discarded rather than
    /// half-read — the safe direction when a user runs an older build
    /// after a newer one.
    @Test func payloadFromANewerVersionFallsBackToDefaults() {
        var future = Preferences.default
        future.version = Preferences.currentVersion + 1
        future.autoRotationEnabled = false
        #expect(Preferences.migrate(from: future) == .default)
    }

    @Test func migrationSanitizesCurrentVersionPayloads() {
        var stored = Preferences.default
        stored.autoRotationDegreesPerSecond = 500
        #expect(Preferences.migrate(from: stored).autoRotationDegreesPerSecond == Preferences.maxRotationSpeed)
    }

    @Test func inMemoryStoreRoundTrips() {
        let store = InMemoryPreferencesStore()
        var preferences = Preferences.default
        preferences.learningModeEnabled = true
        store.save(preferences)
        #expect(store.load().learningModeEnabled)
    }

    @Test func userDefaultsStoreRoundTripsAndRecoversFromCorruption() throws {
        let suiteName = "atlas.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsPreferencesStore(defaults: defaults, key: "test.preferences")
        #expect(store.load() == .default)

        var preferences = Preferences.default
        preferences.dayNightEnabled = false
        preferences.camera = CameraState(yawDegrees: 5, pitchDegrees: 5, distance: 2)
        store.save(preferences)
        #expect(store.load().dayNightEnabled == false)

        // Garbage in the defaults must not stop the app launching.
        defaults.set(Data("not json".utf8), forKey: "test.preferences")
        #expect(store.load() == .default)
    }
}
