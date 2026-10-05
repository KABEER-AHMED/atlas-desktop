import Testing
@testable import AtlasDesktopCore

struct CoordinateTests {
    @Test func acceptsValidBounds() throws {
        _ = try Coordinate(latitude: -90, longitude: -180)
        _ = try Coordinate(latitude: 90, longitude: 180)
        _ = try Coordinate(latitude: 0, longitude: 0)
    }

    @Test func rejectsOutOfBoundsLatitude() {
        #expect(throws: Coordinate.ValidationError.invalidLatitude(91)) {
            try Coordinate(latitude: 91, longitude: 0)
        }
    }

    @Test func rejectsOutOfBoundsLongitude() {
        #expect(throws: Coordinate.ValidationError.invalidLongitude(181)) {
            try Coordinate(latitude: 0, longitude: 181)
        }
    }
}
