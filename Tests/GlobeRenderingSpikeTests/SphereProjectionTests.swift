import Testing
@testable import GlobeRenderingSpike
import AtlasDesktopCore

struct SphereProjectionTests {
    @Test func northPoleProjectsToPositiveY() throws {
        let coord = try Coordinate(latitude: 90.0, longitude: 0.0)
        let p = SphereProjection.point(for: coord)
        #expect(abs(p.y - 1.0) < 1e-9)
        #expect(abs(p.x) < 1e-9)
        #expect(abs(p.z) < 1e-9)
    }

    @Test func primeMeridianEquatorProjectsToPositiveX() throws {
        let coord = try Coordinate(latitude: 0.0, longitude: 0.0)
        let p = SphereProjection.point(for: coord)
        #expect(abs(p.x - 1.0) < 1e-9)
        #expect(abs(p.y) < 1e-9)
        #expect(abs(p.z) < 1e-9)
    }

    @Test func ninetyEastEquatorProjectsToPositiveZ() throws {
        let coord = try Coordinate(latitude: 0.0, longitude: 90.0)
        let p = SphereProjection.point(for: coord)
        #expect(abs(p.x) < 1e-9)
        #expect(abs(p.z - 1.0) < 1e-9)
    }

    @Test func radiusIsRespected() throws {
        let coord = try Coordinate(latitude: 0.0, longitude: 0.0)
        let p = SphereProjection.point(for: coord, radius: 2.5)
        #expect(abs(p.x - 2.5) < 1e-9)
    }
}
