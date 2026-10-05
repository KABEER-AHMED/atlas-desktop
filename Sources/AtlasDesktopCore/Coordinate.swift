import Foundation

/// Canonical domain representation of a geographic point.
/// Latitude/longitude in degrees, per docs/ARCHITECTURE.md's
/// "Coordinate/rendering conventions" — renderer-unit conversion
/// happens explicitly in GlobeRendering, never here.
public struct Coordinate: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public enum ValidationError: Error, Equatable, Sendable {
        case latitudeOutOfRange(Double)
        case longitudeOutOfRange(Double)
    }

    public init(latitude: Double, longitude: Double) throws {
        guard (-90.0...90.0).contains(latitude) else {
            throw ValidationError.latitudeOutOfRange(latitude)
        }
        guard (-180.0...180.0).contains(longitude) else {
            throw ValidationError.longitudeOutOfRange(longitude)
        }
        self.latitude = latitude
        self.longitude = longitude
    }
}
