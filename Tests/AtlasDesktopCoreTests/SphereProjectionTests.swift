import Testing
@testable import AtlasDesktopCore

struct SphereProjectionTests {
    @Test func northPoleProjectsToPositiveY() throws {
        let point = SphereProjection.point(for: try Coordinate(latitude: 90, longitude: 0))
        #expect(abs(point.y - 1.0) < 1e-9)
        #expect(abs(point.x) < 1e-9)
        #expect(abs(point.z) < 1e-9)
    }

    /// Longitude 0 faces the camera, which sits on +Z.
    @Test func primeMeridianOnEquatorFacesTheCamera() throws {
        let point = SphereProjection.point(for: try Coordinate(latitude: 0, longitude: 0))
        #expect(abs(point.z - 1.0) < 1e-9)
        #expect(abs(point.x) < 1e-9)
        #expect(abs(point.y) < 1e-9)
    }

    /// The orientation check that matters: east must run toward +X, so
    /// that east ends up on the right of the screen. A globe with this
    /// reversed passes every round-trip test and renders mirrored.
    @Test func eastRunsTowardPositiveX() throws {
        let east = SphereProjection.point(for: try Coordinate(latitude: 0, longitude: 90))
        #expect(abs(east.x - 1.0) < 1e-9)

        let west = SphereProjection.point(for: try Coordinate(latitude: 0, longitude: -90))
        #expect(abs(west.x + 1.0) < 1e-9)
    }

    @Test func radiusIsRespected() throws {
        let point = SphereProjection.point(for: try Coordinate(latitude: 0, longitude: 0), radius: 2.5)
        #expect(abs(point.z - 2.5) < 1e-9)
    }

    @Test(arguments: [
        (0.0, 0.0), (45.0, 30.0), (-33.9, 151.2), (60.2, -149.9), (-89.0, 179.0), (12.0, -180.0)
    ])
    func projectionRoundTripsThroughItsInverse(latitude: Double, longitude: Double) throws {
        let original = try Coordinate(latitude: latitude, longitude: longitude)
        let point = SphereProjection.point(for: original, radius: 1.7)
        let recovered = try #require(SphereProjection.coordinate(for: point))

        #expect(abs(recovered.latitude - original.latitude) < 1e-9)
        // -180 and +180 are the same meridian; the inverse returns the
        // canonical -180.
        let longitudeDelta = abs(Coordinate.normalizedLongitude(recovered.longitude - original.longitude))
        #expect(longitudeDelta < 1e-9)
    }

    @Test func inverseRejectsTheOrigin() {
        #expect(SphereProjection.coordinate(for: SIMD3(0, 0, 0)) == nil)
    }

    @Test func rayFromTheCameraHitsTheNearSideOfTheSphere() throws {
        let hit = try #require(SphereProjection.intersectSphere(
            rayOrigin: SIMD3(0, 0, 3),
            rayDirection: SIMD3(0, 0, -1)
        ))
        // The near face, not the far one.
        #expect(abs(hit.z - 1.0) < 1e-9)
    }

    @Test func rayMissingTheSphereReturnsNothing() {
        #expect(SphereProjection.intersectSphere(
            rayOrigin: SIMD3(0, 0, 3),
            rayDirection: SIMD3(1, 0, 0)
        ) == nil)
    }

    /// A ray aimed at the limb still hits, and the hit is on the sphere.
    @Test func grazingRayStillLandsOnTheSurface() throws {
        let hit = try #require(SphereProjection.intersectSphere(
            rayOrigin: SIMD3(0, 0, 3),
            rayDirection: SIMD3(0.31, 0, -1)
        ))
        let radius = (hit.x * hit.x + hit.y * hit.y + hit.z * hit.z).squareRoot()
        #expect(abs(radius - 1.0) < 1e-9)
    }
}
