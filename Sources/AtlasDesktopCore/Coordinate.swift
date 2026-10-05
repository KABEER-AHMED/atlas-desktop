import Foundation

/// A validated geographic coordinate in degrees.
///
/// Latitude is clamped-by-validation to [-90, 90] and longitude to
/// [-180, 180]; constructing one out of range is an error rather than a
/// silently wrapped value, so malformed source data surfaces during
/// decoding instead of producing a stray vertex on the globe.
public struct Coordinate: Equatable, Codable, Sendable {
    public enum ValidationError: Error, Equatable {
        case invalidLatitude(Double)
        case invalidLongitude(Double)
    }

    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) throws {
        guard latitude.isFinite, (-90.0...90.0).contains(latitude) else {
            throw ValidationError.invalidLatitude(latitude)
        }

        guard longitude.isFinite, (-180.0...180.0).contains(longitude) else {
            throw ValidationError.invalidLongitude(longitude)
        }

        self.latitude = latitude
        self.longitude = longitude
    }

    /// Normalizes a longitude into [-180, 180). Used when converting a
    /// 3D point back to a coordinate, where accumulated rotation can
    /// produce values outside the canonical range.
    public static func normalizedLongitude(_ longitude: Double) -> Double {
        guard longitude.isFinite else { return 0 }
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value >= 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }
}
