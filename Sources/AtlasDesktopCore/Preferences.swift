import Foundation

/// User-visible preferences, persisted locally.
///
/// Every stored value is run through `sanitized()` on load, so a
/// hand-edited or stale defaults file degrades to safe values instead
/// of producing a stuck globe (a zero rotation speed, a camera inside
/// the sphere, a negative distance). `version` exists so a future
/// format change has somewhere to hook migration; `migrate(from:)`
/// documents the current behaviour for unknown versions.
public struct Preferences: Equatable, Sendable, Codable {
    public static let currentVersion = 1

    /// Bounds for the exposed rotation-speed control. The default is
    /// one full revolution every ~2 minutes: visible motion that is
    /// still calm enough to leave on screen.
    public static let minRotationSpeed = 0.5
    public static let maxRotationSpeed = 12.0
    public static let defaultRotationSpeed = 3.0

    public var version: Int
    public var autoRotationEnabled: Bool
    public var autoRotationDegreesPerSecond: Double
    /// Learning mode: labels hidden, interaction and selection intact.
    public var learningModeEnabled: Bool
    /// Whether labels are drawn at all when not in learning mode.
    public var labelsEnabled: Bool
    public var dayNightEnabled: Bool
    /// When true (the default), the system "reduce motion" setting
    /// suppresses auto-rotation regardless of `autoRotationEnabled`.
    public var respectsReducedMotion: Bool
    public var restoresCameraOnLaunch: Bool
    /// Last camera state, persisted only when `restoresCameraOnLaunch`.
    public var camera: CameraState?

    public static let `default` = Preferences(
        version: currentVersion,
        autoRotationEnabled: true,
        autoRotationDegreesPerSecond: defaultRotationSpeed,
        learningModeEnabled: false,
        labelsEnabled: true,
        dayNightEnabled: true,
        respectsReducedMotion: true,
        restoresCameraOnLaunch: true,
        camera: nil
    )

    public init(
        version: Int = currentVersion,
        autoRotationEnabled: Bool = true,
        autoRotationDegreesPerSecond: Double = defaultRotationSpeed,
        learningModeEnabled: Bool = false,
        labelsEnabled: Bool = true,
        dayNightEnabled: Bool = true,
        respectsReducedMotion: Bool = true,
        restoresCameraOnLaunch: Bool = true,
        camera: CameraState? = nil
    ) {
        self.version = version
        self.autoRotationEnabled = autoRotationEnabled
        self.autoRotationDegreesPerSecond = autoRotationDegreesPerSecond
        self.learningModeEnabled = learningModeEnabled
        self.labelsEnabled = labelsEnabled
        self.dayNightEnabled = dayNightEnabled
        self.respectsReducedMotion = respectsReducedMotion
        self.restoresCameraOnLaunch = restoresCameraOnLaunch
        self.camera = camera
    }

    /// Clamps out-of-range or non-finite values to usable ones.
    public func sanitized() -> Preferences {
        var result = self
        result.version = Self.currentVersion

        if !autoRotationDegreesPerSecond.isFinite {
            result.autoRotationDegreesPerSecond = Self.defaultRotationSpeed
        } else {
            result.autoRotationDegreesPerSecond = max(
                Self.minRotationSpeed,
                min(Self.maxRotationSpeed, autoRotationDegreesPerSecond)
            )
        }

        if let camera {
            // Re-running a decoded camera through the initializer
            // re-applies the pitch/distance clamps, which a
            // hand-edited or older stored value may violate.
            result.camera = CameraState(
                yawDegrees: camera.yawDegrees,
                pitchDegrees: camera.pitchDegrees,
                distance: camera.distance
            )
        }

        return result
    }

    /// Upgrades a decoded payload to the current version.
    ///
    /// Version 1 is the first released format, so there is nothing to
    /// transform yet. A payload claiming a *newer* version than this
    /// build understands is discarded in favour of defaults rather
    /// than half-read, which is the safe direction when a user runs an
    /// older build after a newer one.
    public static func migrate(from decoded: Preferences) -> Preferences {
        guard decoded.version <= currentVersion else { return .default }
        return decoded.sanitized()
    }
}

/// Load/save boundary for preferences, injected so tests never touch
/// the real user defaults.
public protocol PreferencesStore: Sendable {
    func load() -> Preferences
    func save(_ preferences: Preferences)
}

/// An in-memory store for tests and for the (documented) fallback when
/// persistence is unavailable.
public final class InMemoryPreferencesStore: PreferencesStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Preferences

    public init(initial: Preferences = .default) {
        self.stored = initial
    }

    public func load() -> Preferences {
        lock.lock()
        defer { lock.unlock() }
        return Preferences.migrate(from: stored)
    }

    public func save(_ preferences: Preferences) {
        lock.lock()
        defer { lock.unlock() }
        stored = preferences.sanitized()
    }
}

/// `UserDefaults`-backed store: one JSON blob under a single key, so
/// the whole model is versioned and migrated together.
public final class UserDefaultsPreferencesStore: PreferencesStore, @unchecked Sendable {
    public static let defaultsKey = "atlas.preferences.v1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = UserDefaultsPreferencesStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: key) else { return .default }
        guard let decoded = try? JSONDecoder().decode(Preferences.self, from: data) else {
            // Corrupt or incompatible payload: fall back to defaults
            // rather than failing to launch.
            return .default
        }
        return Preferences.migrate(from: decoded)
    }

    public func save(_ preferences: Preferences) {
        guard let data = try? JSONEncoder().encode(preferences.sanitized()) else { return }
        defaults.set(data, forKey: key)
    }
}
