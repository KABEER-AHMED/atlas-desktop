import XCTest
@testable import AtlasDesktopCore

final class CoordinateTests: XCTestCase {
    func testValidCoordinateIsAccepted() throws {
        let c = try Coordinate(latitude: 41.0, longitude: 29.0) // Istanbul
        XCTAssertEqual(c.latitude, 41.0)
        XCTAssertEqual(c.longitude, 29.0)
    }

    func testBoundaryValuesAreAccepted() throws {
        _ = try Coordinate(latitude: 90.0, longitude: 180.0)
        _ = try Coordinate(latitude: -90.0, longitude: -180.0)
    }

    func testOutOfRangeLatitudeThrows() {
        XCTAssertThrowsError(try Coordinate(latitude: 91.0, longitude: 0.0)) { error in
            XCTAssertEqual(error as? Coordinate.ValidationError, .latitudeOutOfRange(91.0))
        }
    }

    func testOutOfRangeLongitudeThrows() {
        XCTAssertThrowsError(try Coordinate(latitude: 0.0, longitude: 181.0)) { error in
            XCTAssertEqual(error as? Coordinate.ValidationError, .longitudeOutOfRange(181.0))
        }
    }
}
