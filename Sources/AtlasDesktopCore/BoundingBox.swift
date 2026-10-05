import Foundation

/// An axis-aligned latitude/longitude bounding box, used to reject
/// most countries cheaply before running point-in-polygon tests.
///
/// Boxes are computed per country *after* the source data's
/// antimeridian splitting, so a box never spans the full longitude
/// range just because a country touches the 180th meridian.
public struct BoundingBox: Equatable, Codable, Sendable {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    public init?(covering coordinates: some Sequence<Coordinate>) {
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity
        var isEmpty = true

        for coordinate in coordinates {
            isEmpty = false
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        guard !isEmpty else { return nil }
        self.init(minLatitude: minLat, maxLatitude: maxLat, minLongitude: minLon, maxLongitude: maxLon)
    }

    public func contains(_ coordinate: Coordinate, tolerance: Double = 0) -> Bool {
        coordinate.latitude >= minLatitude - tolerance
            && coordinate.latitude <= maxLatitude + tolerance
            && coordinate.longitude >= minLongitude - tolerance
            && coordinate.longitude <= maxLongitude + tolerance
    }

    /// Longitude span in degrees. Larger spans mean a country is drawn
    /// wider on screen, which the label level-of-detail rules use.
    public var longitudeSpan: Double { maxLongitude - minLongitude }
    public var latitudeSpan: Double { maxLatitude - minLatitude }

    public func union(_ other: BoundingBox) -> BoundingBox {
        BoundingBox(
            minLatitude: min(minLatitude, other.minLatitude),
            maxLatitude: max(maxLatitude, other.maxLatitude),
            minLongitude: min(minLongitude, other.minLongitude),
            maxLongitude: max(maxLongitude, other.maxLongitude)
        )
    }
}
