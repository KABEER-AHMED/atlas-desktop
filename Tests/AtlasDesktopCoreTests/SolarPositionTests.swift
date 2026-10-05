import Foundation
import Testing
@testable import AtlasDesktopCore

/// The day/night model is an approximation, and these tests pin down how
/// good an approximation it is rather than asserting exact values. The
/// tolerances are the claim being made: about a hundredth of a degree in
/// declination, a few tenths of a degree in longitude.
struct SolarPositionTests {
    private func date(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    @Test func junesolsticeDeclinationMatchesTheObliquityOfTheEcliptic() throws {
        let point = SolarPosition.subsolarPoint(at: try date("2026-06-21T12:00:00Z"))
        #expect(abs(point.latitude - 23.44) < 0.02)
    }

    @Test func decemberSolsticeDeclinationIsTheMirrorImage() throws {
        let point = SolarPosition.subsolarPoint(at: try date("2026-12-21T12:00:00Z"))
        #expect(abs(point.latitude + 23.44) < 0.02)
    }

    @Test(arguments: ["2026-03-20T12:00:00Z", "2026-09-23T00:00:00Z"])
    func equinoxDeclinationIsNearZero(iso: String) throws {
        let point = SolarPosition.subsolarPoint(at: try date(iso))
        #expect(abs(point.latitude) < 0.3)
    }

    /// At noon UTC the sun is over the prime meridian, offset only by
    /// the equation of time — at most about 4° over the year.
    @Test(arguments: [
        "2026-01-15T12:00:00Z", "2026-04-15T12:00:00Z",
        "2026-07-15T12:00:00Z", "2026-11-03T12:00:00Z"
    ])
    func subsolarLongitudeAtNoonUTCIsNearThePrimeMeridian(iso: String) throws {
        let point = SolarPosition.subsolarPoint(at: try date(iso))
        #expect(abs(point.longitude) < 5)
    }

    /// Six hours of rotation moves the subsolar point 90° west.
    @Test func subsolarLongitudeTracksTheEarthsRotation() throws {
        let noon = SolarPosition.subsolarPoint(at: try date("2026-05-10T12:00:00Z"))
        let evening = SolarPosition.subsolarPoint(at: try date("2026-05-10T18:00:00Z"))
        let delta = Coordinate.normalizedLongitude(evening.longitude - noon.longitude)
        #expect(abs(delta + 90) < 0.5)
    }

    @Test func directionIsAUnitVectorPointingAtTheSubsolarPoint() throws {
        let moment = try date("2026-08-01T09:30:00Z")
        let direction = SolarPosition.directionInModelSpace(at: moment)
        let length = (direction.x * direction.x + direction.y * direction.y + direction.z * direction.z).squareRoot()
        #expect(abs(length - 1) < 1e-9)

        let recovered = try #require(SphereProjection.coordinate(for: direction))
        let expected = SolarPosition.subsolarPoint(at: moment)
        #expect(abs(recovered.latitude - expected.latitude) < 1e-9)
    }

    /// Deterministic: the same instant always gives the same answer, so
    /// a render of a fixed date is reproducible.
    @Test func resultsAreDeterministic() throws {
        let moment = try date("2026-02-02T02:02:02Z")
        #expect(SolarPosition.subsolarPoint(at: moment) == SolarPosition.subsolarPoint(at: moment))
    }
}
