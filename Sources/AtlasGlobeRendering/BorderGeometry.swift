import Foundation
import SceneKit
import AtlasDesktopCore

/// Turns country outlines into line geometry on the sphere.
///
/// Every ring is closed, split at the antimeridian, and densified
/// before projection: the source data has vertices up to several
/// degrees apart, and a straight 3D segment between two such points
/// visibly cuts through the sphere. Subdividing long segments before
/// projecting keeps the outline on the surface.
///
/// All countries' borders go into **one** geometry rather than one per
/// country — a single draw call for ~20k segments instead of 177 — and
/// the selected country gets its own small geometry drawn on top.
public enum BorderGeometry {
    /// Longest segment, in degrees, left unsubdivided. At 1.5° the
    /// deviation of the chord from the sphere is well under a pixel at
    /// the closest zoom.
    public static let maxSegmentDegrees = 1.5

    /// Line geometry for the outlines of `countries`.
    public static func outlineGeometry(
        for countries: [Country],
        radius: Double,
        color: NSColor
    ) -> SCNGeometry? {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []

        for country in countries {
            for polygon in country.geometry.polygons {
                for ring in polygon.allRings {
                    appendRing(ring, radius: radius, vertices: &vertices, indices: &indices)
                }
            }
        }

        return geometry(vertices: vertices, indices: indices, color: color)
    }

    private static func appendRing(
        _ ring: GeoRing,
        radius: Double,
        vertices: inout [SCNVector3],
        indices: inout [Int32]
    ) {
        for run in Antimeridian.split(path: ring.closedCoordinates) {
            let densified = densify(path: run)
            guard densified.count >= 2 else { continue }

            let firstIndex = Int32(vertices.count)
            for coordinate in densified {
                let point = SphereProjection.point(for: coordinate, radius: radius)
                vertices.append(SCNVector3(Float(point.x), Float(point.y), Float(point.z)))
            }
            for offset in 0..<(densified.count - 1) {
                indices.append(firstIndex + Int32(offset))
                indices.append(firstIndex + Int32(offset + 1))
            }
        }
    }

    /// Inserts intermediate points so no segment exceeds
    /// `maxSegmentDegrees`. Linear interpolation in lat/lon, which for
    /// segments this short is indistinguishable from a great-circle
    /// path and avoids the pole-adjacent edge cases of slerp.
    static func densify(path: [Coordinate]) -> [Coordinate] {
        guard path.count >= 2 else { return path }

        var result: [Coordinate] = [path[0]]
        result.reserveCapacity(path.count)

        for index in 1..<path.count {
            let start = path[index - 1]
            let end = path[index]
            let deltaLatitude = end.latitude - start.latitude
            let deltaLongitude = end.longitude - start.longitude
            // Longitude degrees converge toward the poles, so weight
            // them by cos(latitude): a 10° longitude step near the pole
            // is a short distance and needs no subdivision.
            let meanLatitude = (start.latitude + end.latitude) / 2 * .pi / 180
            let scaledLongitude = deltaLongitude * cos(meanLatitude)
            let distance = (deltaLatitude * deltaLatitude + scaledLongitude * scaledLongitude).squareRoot()

            let steps = max(1, Int((distance / maxSegmentDegrees).rounded(.up)))
            if steps > 1 {
                for step in 1..<steps {
                    let t = Double(step) / Double(steps)
                    if let interpolated = try? Coordinate(
                        latitude: start.latitude + deltaLatitude * t,
                        longitude: start.longitude + deltaLongitude * t
                    ) {
                        result.append(interpolated)
                    }
                }
            }
            result.append(end)
        }

        return result
    }

    static func geometry(vertices: [SCNVector3], indices: [Int32], color: NSColor) -> SCNGeometry? {
        guard vertices.count >= 2, indices.count >= 2 else { return nil }

        let source = SCNGeometrySource(vertices: vertices)
        let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: data,
            primitiveType: .line,
            primitiveCount: indices.count / 2,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        // Borders are a cartographic layer, not a lit surface: they must
        // stay legible on the night side of the terminator.
        material.lightingModel = .constant
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}
