import Foundation

/// A closed linear ring of coordinates.
///
/// The decoder stores rings without a duplicated closing vertex: the
/// last point implicitly connects back to the first. GeoJSON requires
/// the duplicate, so `init(closedRing:)` strips it. Degenerate rings
/// (fewer than three distinct points) are rejected, since they can
/// neither be filled nor outlined meaningfully.
public struct GeoRing: Equatable, Sendable {
    public enum ValidationError: Error, Equatable {
        case tooFewPoints(Int)
    }

    public let coordinates: [Coordinate]

    public init(coordinates: [Coordinate]) throws {
        var points = coordinates
        if points.count > 1, points.first == points.last {
            points.removeLast()
        }
        guard points.count >= 3 else {
            throw ValidationError.tooFewPoints(points.count)
        }
        self.coordinates = points
    }

    /// The ring's vertices followed by the first vertex again, for
    /// drawing a closed outline.
    public var closedCoordinates: [Coordinate] {
        guard let first = coordinates.first else { return [] }
        return coordinates + [first]
    }

    /// Signed area in degree-space (shoelace). Only the magnitude and
    /// sign are used — as a relative size heuristic for label
    /// level-of-detail and for picking a country's largest polygon —
    /// never as a real surface area in square kilometres.
    public var signedPlanarArea: Double {
        guard coordinates.count >= 3 else { return 0 }
        var sum = 0.0
        for index in coordinates.indices {
            let current = coordinates[index]
            let next = coordinates[(index + 1) % coordinates.count]
            sum += current.longitude * next.latitude - next.longitude * current.latitude
        }
        return sum / 2
    }

    public var boundingBox: BoundingBox {
        // Safe to force: a validated ring always has >= 3 coordinates.
        BoundingBox(covering: coordinates)!
    }

    /// Even-odd ray crossing test in longitude/latitude space.
    public func containsPoint(_ coordinate: Coordinate) -> Bool {
        var isInside = false
        let x = coordinate.longitude
        let y = coordinate.latitude

        var j = coordinates.count - 1
        for i in coordinates.indices {
            let xi = coordinates[i].longitude
            let yi = coordinates[i].latitude
            let xj = coordinates[j].longitude
            let yj = coordinates[j].latitude

            if (yi > y) != (yj > y) {
                let t = (y - yi) / (yj - yi)
                if x < xi + t * (xj - xi) {
                    isInside.toggle()
                }
            }
            j = i
        }
        return isInside
    }
}

/// A polygon: one outer ring plus zero or more hole rings.
public struct GeoPolygon: Equatable, Sendable {
    public let outerRing: GeoRing
    public let holes: [GeoRing]

    public init(outerRing: GeoRing, holes: [GeoRing] = []) {
        self.outerRing = outerRing
        self.holes = holes
    }

    public var boundingBox: BoundingBox { outerRing.boundingBox }

    public var allRings: [GeoRing] { [outerRing] + holes }

    /// A point is inside the polygon when it is inside the outer ring
    /// and inside none of the holes (Lesotho inside South Africa, the
    /// Vatican inside Italy, and so on).
    public func containsPoint(_ coordinate: Coordinate) -> Bool {
        guard outerRing.boundingBox.contains(coordinate) else { return false }
        guard outerRing.containsPoint(coordinate) else { return false }
        return !holes.contains { $0.containsPoint(coordinate) }
    }
}

/// All polygons belonging to one country, with a precomputed bounding
/// box and relative size so hit-testing and label layout never have to
/// rescan the geometry.
public struct CountryGeometry: Equatable, Sendable {
    public enum ValidationError: Error, Equatable {
        case noPolygons
    }

    public let polygons: [GeoPolygon]
    public let boundingBox: BoundingBox
    /// Sum of |outer ring area| in degree-space; a relative size
    /// heuristic only (see `GeoRing.signedPlanarArea`).
    public let relativeSize: Double

    public init(polygons: [GeoPolygon]) throws {
        guard let first = polygons.first else {
            throw ValidationError.noPolygons
        }
        self.polygons = polygons
        self.boundingBox = polygons.dropFirst().reduce(first.boundingBox) { $0.union($1.boundingBox) }
        self.relativeSize = polygons.reduce(0) { $0 + abs($1.outerRing.signedPlanarArea) }
    }

    public func containsPoint(_ coordinate: Coordinate) -> Bool {
        guard boundingBox.contains(coordinate) else { return false }
        return polygons.contains { $0.containsPoint(coordinate) }
    }

    /// The largest polygon by outer-ring area — the mainland for most
    /// countries. Used as a fallback label anchor when the dataset has
    /// no explicit label point.
    public var largestPolygon: GeoPolygon? {
        polygons.max { abs($0.outerRing.signedPlanarArea) < abs($1.outerRing.signedPlanarArea) }
    }
}
