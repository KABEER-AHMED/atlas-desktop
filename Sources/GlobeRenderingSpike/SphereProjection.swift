import Foundation // for cos/sin — SIMD3 itself is a stdlib type, no simd import needed
import AtlasDesktopCore

/// Converts a geographic `Coordinate` to a point on a unit sphere, in a
/// documented convention (per docs/ARCHITECTURE.md:
/// "Document sphere orientation, prime meridian, north pole, camera up
/// vector, coordinate handedness, and transforms").
///
/// Convention used here:
/// - Right-handed coordinate system.
/// - +Y is the north pole (latitude +90).
/// - Prime meridian (longitude 0) lies in the +X/+Y plane at the
///   equator, pointing toward +X.
/// - Longitude increases eastward, which in this convention rotates
///   from +X toward +Z.
///
/// This is the one and only place lat/lon-to-3D conversion should
/// happen — country selection (hit-testing) must reuse this, never a
/// second, possibly-inconsistent projection.
public enum SphereProjection {
    public static func point(for coordinate: Coordinate, radius: Double = 1.0) -> SIMD3<Double> {
        let latRad = coordinate.latitude * .pi / 180.0
        let lonRad = coordinate.longitude * .pi / 180.0

        let x = radius * cos(latRad) * cos(lonRad)
        let y = radius * sin(latRad)
        let z = radius * cos(latRad) * sin(lonRad)

        return SIMD3<Double>(x, y, z)
    }
}
