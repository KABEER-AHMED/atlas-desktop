import Foundation

/// Converts between geographic coordinates and points on a sphere.
///
/// Convention (also recorded in docs/ARCHITECTURE.md):
/// - Right-handed coordinate system.
/// - +Y is the north pole (latitude +90).
/// - Longitude 0 at the equator points toward +Z — toward the camera,
///   which sits on +Z looking at the origin.
/// - Longitude increases eastward, rotating +Z toward +X.
///
/// The last point is the one that matters and the one that is easy to
/// get wrong: with the camera on +Z, east has to run toward +X so that
/// east appears on the **right** of the screen. Sending east toward +Z
/// instead produces a globe that is correct in every numerical test and
/// mirrored on screen.
///
/// This is the only lat/lon-to-3D conversion in the project. Country
/// selection reuses `coordinate(for:)`, the exact inverse of
/// `point(for:)`, so a click maps back through the same transform the
/// geometry was built with.
public enum SphereProjection {
    public static func point(for coordinate: Coordinate, radius: Double = 1.0) -> SIMD3<Double> {
        let latitude = coordinate.latitude * .pi / 180.0
        let longitude = coordinate.longitude * .pi / 180.0

        return SIMD3<Double>(
            radius * cos(latitude) * sin(longitude),
            radius * sin(latitude),
            radius * cos(latitude) * cos(longitude)
        )
    }

    /// Inverse of `point(for:)`. The input need not be normalized; only
    /// its direction matters.
    public static func coordinate(for point: SIMD3<Double>) -> Coordinate? {
        let length = (point.x * point.x + point.y * point.y + point.z * point.z).squareRoot()
        guard length > 0, length.isFinite else { return nil }

        let normalizedY = max(-1.0, min(1.0, point.y / length))
        let latitude = asin(normalizedY) * 180.0 / .pi
        let longitude = atan2(point.x, point.z) * 180.0 / .pi

        return try? Coordinate(
            latitude: max(-90, min(90, latitude)),
            longitude: Coordinate.normalizedLongitude(longitude)
        )
    }

    /// Nearest intersection of a ray with a sphere centred at the
    /// origin, or `nil` when the ray misses it. Used to turn a click in
    /// the globe view into a point on the globe's surface.
    public static func intersectSphere(
        rayOrigin: SIMD3<Double>,
        rayDirection: SIMD3<Double>,
        radius: Double = 1.0
    ) -> SIMD3<Double>? {
        let direction = normalize(rayDirection)
        guard direction != .zero else { return nil }

        let b = 2 * dot(rayOrigin, direction)
        let c = dot(rayOrigin, rayOrigin) - radius * radius
        let discriminant = b * b - 4 * c
        guard discriminant >= 0 else { return nil }

        let root = discriminant.squareRoot()
        let t1 = (-b - root) / 2
        let t2 = (-b + root) / 2
        // Prefer the near hit; fall back to the far one when the origin
        // is inside the sphere.
        let t = t1 > 0 ? t1 : t2
        guard t > 0 else { return nil }

        return rayOrigin + direction * t
    }

    public static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    public static func normalize(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        let length = dot(vector, vector).squareRoot()
        guard length > 0, length.isFinite else { return .zero }
        return vector / length
    }
}
