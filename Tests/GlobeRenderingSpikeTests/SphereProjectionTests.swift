import XCTest
@testable import GlobeRenderingSpike
import AtlasDesktopCore

final class SphereProjectionTests: XCTestCase {
    func testNorthPoleProjectsToPositiveY() throws {
        let coord = try Coordinate(latitude: 90.0, longitude: 0.0)
        let p = SphereProjection.point(for: coord)
        XCTAssertEqual(p.y, 1.0, accuracy: 1e-9)
        XCTAssertEqual(p.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(p.z, 0.0, accuracy: 1e-9)
    }

    func testPrimeMeridianEquatorProjectsToPositiveX() throws {
        let coord = try Coordinate(latitude: 0.0, longitude: 0.0)
        let p = SphereProjection.point(for: coord)
        XCTAssertEqual(p.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(p.y, 0.0, accuracy: 1e-9)
        XCTAssertEqual(p.z, 0.0, accuracy: 1e-9)
    }

    func test90EastEquatorProjectsToPositiveZ() throws {
        let coord = try Coordinate(latitude: 0.0, longitude: 90.0)
        let p = SphereProjection.point(for: coord)
        XCTAssertEqual(p.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(p.z, 1.0, accuracy: 1e-9)
    }

    func testRadiusIsRespected() throws {
        let coord = try Coordinate(latitude: 0.0, longitude: 0.0)
        let p = SphereProjection.point(for: coord, radius: 2.5)
        XCTAssertEqual(p.x, 2.5, accuracy: 1e-9)
    }
}
