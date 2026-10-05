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

    /// NaN reaching the geometry would produce vertices that silently
    /// corrupt a whole country's outline, so it is rejected at the door.
    @Test func rejectsNonFiniteValues() {
        #expect(throws: (any Error).self) { try Coordinate(latitude: .nan, longitude: 0) }
        #expect(throws: (any Error).self) { try Coordinate(latitude: 0, longitude: .infinity) }
    }

    @Test func normalizesLongitudeIntoCanonicalRange() {
        #expect(Coordinate.normalizedLongitude(190) == -170)
        #expect(Coordinate.normalizedLongitude(-190) == 170)
        #expect(Coordinate.normalizedLongitude(540) == 180 - 360)
        #expect(Coordinate.normalizedLongitude(0) == 0)
        #expect(Coordinate.normalizedLongitude(-180) == -180)
    }
}
