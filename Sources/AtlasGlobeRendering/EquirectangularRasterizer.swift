import Foundation
import AtlasDesktopCore

/// A country index per pixel of an equirectangular (plate carrée) grid.
///
/// Index 0 is ocean; any other value is `countryIDs[value - 1]`. This is
/// what the globe's land fill and selection highlight are built from:
/// one rasterization at load time produces both textures, and a new
/// selection only needs the cheap pass in `GlobeTextureFactory` rather
/// than any re-triangulation.
public struct CountryIndexMap: Sendable {
    public let width: Int
    public let height: Int
    public let indices: [UInt16]
    public let countryIDs: [CountryID]

    public init(width: Int, height: Int, indices: [UInt16], countryIDs: [CountryID]) {
        self.width = width
        self.height = height
        self.indices = indices
        self.countryIDs = countryIDs
    }

    public func pixel(for coordinate: Coordinate) -> (x: Int, y: Int) {
        let x = Int(((coordinate.longitude + 180) / 360) * Double(width))
        let y = Int(((90 - coordinate.latitude) / 180) * Double(height))
        return (max(0, min(width - 1, x)), max(0, min(height - 1, y)))
    }

    /// The country covering `coordinate` according to the raster.
    ///
    /// This is the *rendered* answer, which is why it exists: a test can
    /// compare it against `CountryLookup`'s exact point-in-polygon
    /// answer and catch the two drifting apart. Selection itself always
    /// uses `CountryLookup`, never this.
    public func countryID(at coordinate: Coordinate) -> CountryID? {
        let point = pixel(for: coordinate)
        let value = indices[point.y * width + point.x]
        guard value > 0, Int(value) <= countryIDs.count else { return nil }
        return countryIDs[Int(value) - 1]
    }
}

/// Scanline polygon fill in longitude/latitude space.
///
/// Even-odd filling across a polygon's outer ring *and* its holes in one
/// intersection list, which is what makes holes (the Vatican in Italy,
/// Lesotho in South Africa) come out as holes without any special case.
///
/// Countries are drawn largest-first so that where the source data
/// overlaps — an enclave with no matching hole in its neighbour — the
/// smaller country ends up on top. That matches `CountryLookup`'s
/// smaller-country-wins rule, so what is drawn and what is selected
/// agree.
public enum EquirectangularRasterizer {
    /// 2048×1024 is one pixel per ~0.18° — finer than the 1:110m source
    /// data's own vertex spacing, so the raster is not the limiting
    /// factor in how the fill looks. Borders are drawn as vector lines
    /// on top and stay crisp at any zoom regardless of this.
    public static let defaultWidth = 2048
    public static let defaultHeight = 1024

    public static func rasterize(
        countries: [Country],
        width: Int = defaultWidth,
        height: Int = defaultHeight
    ) -> CountryIndexMap {
        precondition(width > 1 && height > 1, "raster dimensions must be positive")

        var indices = [UInt16](repeating: 0, count: width * height)
        let ordered = countries.enumerated().sorted {
            $0.element.geometry.relativeSize > $1.element.geometry.relativeSize
        }

        let degreesPerRow = 180.0 / Double(height)

        for (originalIndex, country) in ordered {
            let value = UInt16(originalIndex + 1)
            var wroteAnyPixel = false

            for polygon in country.geometry.polygons {
                let box = polygon.boundingBox
                // Rows whose sample latitude can fall inside the box.
                let firstRow = max(0, Int(((90 - box.maxLatitude) / 180) * Double(height)) - 1)
                let lastRow = min(height - 1, Int(((90 - box.minLatitude) / 180) * Double(height)) + 1)
                guard firstRow <= lastRow else { continue }

                let rings = polygon.allRings
                var crossings: [Double] = []

                for row in firstRow...lastRow {
                    let latitude = 90 - (Double(row) + 0.5) * degreesPerRow
                    crossings.removeAll(keepingCapacity: true)

                    for ring in rings {
                        let points = ring.coordinates
                        var previous = points[points.count - 1]
                        for point in points {
                            if (previous.latitude > latitude) != (point.latitude > latitude) {
                                let t = (latitude - previous.latitude) / (point.latitude - previous.latitude)
                                crossings.append(previous.longitude + t * (point.longitude - previous.longitude))
                            }
                            previous = point
                        }
                    }

                    guard crossings.count >= 2 else { continue }
                    crossings.sort()

                    let rowOffset = row * width
                    var pairIndex = 0
                    while pairIndex + 1 < crossings.count {
                        let startLongitude = crossings[pairIndex]
                        let endLongitude = crossings[pairIndex + 1]
                        pairIndex += 2

                        var startX = Int(((startLongitude + 180) / 360) * Double(width))
                        var endX = Int(((endLongitude + 180) / 360) * Double(width))
                        startX = max(0, min(width - 1, startX))
                        endX = max(0, min(width - 1, endX))
                        guard startX <= endX else { continue }

                        for x in startX...endX {
                            indices[rowOffset + x] = value
                        }
                        wroteAnyPixel = true
                    }
                }
            }

            // A country smaller than one raster cell in both axes can
            // miss every sample row. Rather than vanish from the fill
            // (its vector border would still be drawn, which would look
            // like a bug), it gets the single pixel nearest its label
            // anchor.
            if !wroteAnyPixel {
                let box = country.geometry.boundingBox
                let centre = try? Coordinate(
                    latitude: (box.minLatitude + box.maxLatitude) / 2,
                    longitude: (box.minLongitude + box.maxLongitude) / 2
                )
                if let centre {
                    let x = max(0, min(width - 1, Int(((centre.longitude + 180) / 360) * Double(width))))
                    let y = max(0, min(height - 1, Int(((90 - centre.latitude) / 180) * Double(height))))
                    indices[y * width + x] = value
                }
            }
        }

        return CountryIndexMap(
            width: width,
            height: height,
            indices: indices,
            countryIDs: countries.map(\.id)
        )
    }
}
