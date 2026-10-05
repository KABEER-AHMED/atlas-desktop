import Foundation

/// Splits coordinate paths that jump across the 180th meridian.
///
/// Natural Earth already splits its polygons at ±180, so in practice
/// this is a guard rather than a transform: without it, a single ring
/// containing both +179.9 and -179.9 would be drawn as a line straight
/// across the globe. The splitter is applied to every outline before it
/// becomes GPU geometry, and tested against Fiji and Russia, the two
/// shapes in the dataset that sit on the meridian.
public enum Antimeridian {
    /// A longitude step larger than this is interpreted as a wrap
    /// rather than real eastward travel. Half the globe is the only
    /// defensible threshold: no real adjacent vertex pair in a country
    /// outline spans more than 180°.
    public static let wrapThreshold = 180.0

    /// Splits a path into runs that contain no wrap. A path with no
    /// wrap comes back as a single run.
    public static func split(path: [Coordinate]) -> [[Coordinate]] {
        guard path.count > 1 else { return path.isEmpty ? [] : [path] }

        var runs: [[Coordinate]] = []
        var current: [Coordinate] = [path[0]]

        for index in 1..<path.count {
            let previous = path[index - 1]
            let point = path[index]
            if abs(point.longitude - previous.longitude) > wrapThreshold {
                runs.append(current)
                current = [point]
            } else {
                current.append(point)
            }
        }
        runs.append(current)

        return runs.filter { $0.count > 1 }
    }

    /// True when any adjacent pair in the path wraps.
    public static func crossesAntimeridian(path: [Coordinate]) -> Bool {
        guard path.count > 1 else { return false }
        for index in 1..<path.count {
            if abs(path[index].longitude - path[index - 1].longitude) > wrapThreshold {
                return true
            }
        }
        return false
    }
}
