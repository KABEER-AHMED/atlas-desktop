import Foundation

public struct Coordinate: Equatable, Codable, Sendable {
    public enum ValidationError: Error, Equatable {
        case invalidLatitude(Double)
        case invalidLongitude(Double)
    }

    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) throws {
        guard (-90.0...90.0).contains(latitude) else {
            throw ValidationError.invalidLatitude(latitude)
        }

        guard (-180.0...180.0).contains(longitude) else {
            throw ValidationError.invalidLongitude(longitude)
        }

        self.latitude = latitude
        self.longitude = longitude
    }
}
