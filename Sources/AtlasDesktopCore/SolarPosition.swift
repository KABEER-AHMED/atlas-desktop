import Foundation

/// The subsolar point — the coordinate where the sun is directly
/// overhead — used to orient the globe's day/night lighting.
///
/// ## Accuracy
///
/// This is the **low-precision** solar-position algorithm published in
/// the Astronomical Almanac (the same one NOAA's solar calculator
/// documents): mean longitude and anomaly linear in time, a two-term
/// equation-of-centre correction, and mean sidereal time. It omits
/// nutation, aberration, lunar perturbations, topocentric parallax and
/// atmospheric refraction, and it treats UTC as TT (ignoring leap
/// seconds).
///
/// Expected error is on the order of 0.01° in declination and a few
/// arcminutes in longitude for dates within a few decades of 2000 —
/// around a kilometre of terminator position on a globe whose rendered
/// terminator is a soft gradient tens of kilometres wide. It is an
/// **approximation suitable for shading**, not an ephemeris, and
/// nothing in the app claims astronomical precision. No network access
/// is involved; it is pure arithmetic on the system clock.
public enum SolarPosition {
    /// Days from the J2000.0 epoch (2000-01-01 12:00 UTC).
    static func julianDaysSinceJ2000(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400.0 - 10_957.5
    }

    /// The sun's declination and the subsolar longitude for `date`.
    public static func subsolarPoint(at date: Date) -> Coordinate {
        let n = julianDaysSinceJ2000(date)

        // Mean longitude and mean anomaly of the sun, in degrees.
        let meanLongitude = 280.460 + 0.9856474 * n
        let meanAnomaly = (357.528 + 0.9856003 * n) * .pi / 180

        // Apparent ecliptic longitude: mean longitude plus the
        // equation of centre (two terms).
        let eclipticLongitude = (meanLongitude
            + 1.915 * sin(meanAnomaly)
            + 0.020 * sin(2 * meanAnomaly)) * .pi / 180

        // Obliquity of the ecliptic, in radians.
        let obliquity = (23.439 - 0.0000004 * n) * .pi / 180

        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(
            cos(obliquity) * sin(eclipticLongitude),
            cos(eclipticLongitude)
        )

        // Greenwich mean sidereal time, in degrees.
        let siderealHours = 18.697374558 + 24.06570982441908 * n
        let siderealDegrees = siderealHours * 15

        let longitude = Coordinate.normalizedLongitude(
            rightAscension * 180 / .pi - siderealDegrees
        )
        let latitude = max(-90, min(90, declination * 180 / .pi))

        // Both components are clamped/normalized above, so this cannot
        // fail; fall back to the equator rather than trapping if the
        // system clock ever produces a non-finite interval.
        return (try? Coordinate(latitude: latitude, longitude: longitude))
            ?? ((try? Coordinate(latitude: 0, longitude: 0))!)
    }

    /// Unit vector from the globe's centre toward the sun, in
    /// globe-model space. The renderer places its directional light
    /// along this vector.
    public static func directionInModelSpace(at date: Date) -> SIMD3<Double> {
        SphereProjection.point(for: subsolarPoint(at: date))
    }
}
