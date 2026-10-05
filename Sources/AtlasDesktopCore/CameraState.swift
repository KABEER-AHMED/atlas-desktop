import Foundation

/// The globe's orientation and the camera's distance from it.
///
/// Rotation lives on the globe (a model rotation), not the camera: the
/// camera stays at +Z looking at the origin with +Y up, so the view can
/// never roll or end up upside down.
///
/// The convention is chosen so the two stored angles are directly
/// meaningful, which is what makes them testable and worth persisting:
/// - `yawDegrees` is the **longitude** at the centre of the view.
/// - `pitchDegrees` is the **latitude** at the centre of the view.
///
/// `SphereProjection` puts longitude 0 on +Z, facing the camera, so
/// bringing longitude `yaw` to the centre means rotating the globe by
/// `-yaw` about Y. That sign is applied in exactly one place,
/// `modelEulerAngles`, which the renderer and hit-testing both use.
public struct CameraState: Equatable, Sendable, Codable {
    public var yawDegrees: Double
    public var pitchDegrees: Double
    /// Camera distance from the globe's centre, in globe radii.
    public var distance: Double

    /// Pitch stops short of ±90° so the poles stay below the top of the
    /// view and the up vector never degenerates.
    public static let maxPitch = 85.0
    public static let minDistance = 1.35
    public static let maxDistance = 6.0
    public static let defaultDistance = 3.0

    /// Longitude 0 on the equator at the default distance.
    public static let home = CameraState(yawDegrees: 0, pitchDegrees: 0, distance: defaultDistance)

    public init(yawDegrees: Double = 0, pitchDegrees: Double = 0, distance: Double = defaultDistance) {
        self.yawDegrees = Self.normalizedYaw(yawDegrees)
        self.pitchDegrees = Self.clampPitch(pitchDegrees)
        self.distance = Self.clampDistance(distance)
    }

    // MARK: - Bounds

    public static func normalizedYaw(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        var yaw = value.truncatingRemainder(dividingBy: 360)
        if yaw > 180 { yaw -= 360 }
        if yaw <= -180 { yaw += 360 }
        return yaw
    }

    public static func clampPitch(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(-maxPitch, min(maxPitch, value))
    }

    public static func clampDistance(_ value: Double) -> Double {
        guard value.isFinite else { return defaultDistance }
        return max(minDistance, min(maxDistance, value))
    }

    public var isAtMinimumDistance: Bool { distance <= Self.minDistance + 1e-9 }
    public var isAtMaximumDistance: Bool { distance >= Self.maxDistance - 1e-9 }

    // MARK: - Interaction

    /// Applies a pointer drag, with the globe following the pointer: a
    /// point grabbed and dragged right moves right.
    ///
    /// `deltaX` is pointer movement to the right and `deltaY` movement
    /// upward, both in view points. `degreesPerPoint` comes from the
    /// view so a drag covers the same arc at any window size, and is
    /// scaled by distance so the apparent speed under the cursor stays
    /// roughly constant as the camera moves in.
    public mutating func applyDrag(deltaX: Double, deltaY: Double, degreesPerPoint: Double) {
        guard deltaX.isFinite, deltaY.isFinite, degreesPerPoint.isFinite else { return }
        let scale = degreesPerPoint * (distance / Self.defaultDistance)
        yawDegrees = Self.normalizedYaw(yawDegrees - deltaX * scale)
        pitchDegrees = Self.clampPitch(pitchDegrees - deltaY * scale)
    }

    /// Multiplicative zoom, so one notch changes the view by the same
    /// proportion at any distance. `factor` below 1 moves closer.
    public mutating func applyZoom(factor: Double) {
        guard factor > 0, factor.isFinite else { return }
        distance = Self.clampDistance(distance * factor)
    }

    public mutating func advanceAutoRotation(degreesPerSecond: Double, elapsed: TimeInterval) {
        guard elapsed > 0, elapsed.isFinite, degreesPerSecond.isFinite else { return }
        yawDegrees = Self.normalizedYaw(yawDegrees + degreesPerSecond * elapsed)
    }

    // MARK: - Transforms

    /// Euler angles for the globe node, in radians, applied in
    /// SceneKit's z-y-x order (so the composed rotation is
    /// `Rx(pitch) · Ry(-yaw)`).
    public var modelEulerAngles: (x: Double, y: Double, z: Double) {
        (x: pitchDegrees * .pi / 180, y: -yawDegrees * .pi / 180, z: 0)
    }

    /// Rotates a point from globe-model space into world space.
    public func worldPoint(forModel point: SIMD3<Double>) -> SIMD3<Double> {
        let angles = modelEulerAngles
        return Self.rotateX(Self.rotateY(point, radians: angles.y), radians: angles.x)
    }

    /// Rotates a world-space point back into globe-model space — the
    /// exact inverse of `worldPoint(forModel:)`, used to turn a click on
    /// the sphere into a geographic coordinate.
    public func modelPoint(forWorld point: SIMD3<Double>) -> SIMD3<Double> {
        let angles = modelEulerAngles
        return Self.rotateY(Self.rotateX(point, radians: -angles.x), radians: -angles.y)
    }

    /// The camera's position in world space.
    public var cameraPosition: SIMD3<Double> { SIMD3(0, 0, distance) }

    /// The coordinate at the centre of the view. By construction this
    /// is `(pitchDegrees, yawDegrees)`; it is derived through the real
    /// transforms rather than returned directly, so the test that
    /// checks it also checks the transforms.
    public var centerCoordinate: Coordinate? {
        SphereProjection.coordinate(for: modelPoint(forWorld: SIMD3(0, 0, 1)))
    }

    static func rotateY(_ point: SIMD3<Double>, radians: Double) -> SIMD3<Double> {
        let c = cos(radians), s = sin(radians)
        return SIMD3(c * point.x + s * point.z, point.y, -s * point.x + c * point.z)
    }

    static func rotateX(_ point: SIMD3<Double>, radians: Double) -> SIMD3<Double> {
        let c = cos(radians), s = sin(radians)
        return SIMD3(point.x, c * point.y - s * point.z, s * point.y + c * point.z)
    }
}
