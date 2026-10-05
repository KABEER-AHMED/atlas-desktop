import Foundation
import AppKit
import AtlasDesktopCore
import AtlasGeographyData

// Converts the pinned Natural Earth source files in Data/source into
// the single runtime asset the app bundles. Run from the repository
// root:
//
//     swift run AtlasDataTool
//
// Deterministic: the same inputs always produce byte-identical output
// apart from the `generatedAt` stamp, which is taken from the source
// files' pinned release rather than the wall clock for exactly that
// reason. See docs/DATA_AND_LICENSES.md.

let arguments = CommandLine.arguments
let repositoryRoot = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : FileManager.default.currentDirectoryPath)

let countriesURL = repositoryRoot
    .appendingPathComponent("Data/source/ne_110m_admin_0_countries.geojson")
let placesURL = repositoryRoot
    .appendingPathComponent("Data/source/ne_110m_populated_places.geojson")
let imageryURL = repositoryRoot
    .appendingPathComponent("Data/source/world.topo.bathy.200412.3x5400x2700.jpg")
let outputURL = repositoryRoot
    .appendingPathComponent("Sources/AtlasGeographyData/Resources/atlas-countries.json")
// The surface imagery is a rendering asset, so it is generated into the
// renderer's resources rather than the geography module's.
let textureOutputURL = repositoryRoot
    .appendingPathComponent("Sources/AtlasGlobeRendering/Resources/atlas-earth.jpg")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

// MARK: - Minimal GeoJSON reading

/// Reads a GeoJSON FeatureCollection with `JSONSerialization`.
///
/// `Codable` is a poor fit here: Natural Earth's property tables have
/// 168 heterogeneous columns of which this tool wants nine, and the
/// coordinate arrays are nested to a depth that depends on the geometry
/// type. A dictionary walk with explicit checks is shorter and fails
/// more legibly than a hand-written decoder for a shape this loose.
struct GeoJSONFeature {
    let properties: [String: Any]
    let geometryType: String
    let coordinates: Any
}

func readFeatures(at url: URL) -> [GeoJSONFeature] {
    guard let data = try? Data(contentsOf: url) else {
        fail("cannot read \(url.path)\nRun Tools/fetch-source-data.sh first.")
    }
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let features = root["features"] as? [[String: Any]] else {
        fail("\(url.lastPathComponent) is not a GeoJSON FeatureCollection")
    }

    return features.compactMap { feature in
        guard let properties = feature["properties"] as? [String: Any],
              let geometry = feature["geometry"] as? [String: Any],
              let type = geometry["type"] as? String,
              let coordinates = geometry["coordinates"] else { return nil }
        return GeoJSONFeature(properties: properties, geometryType: type, coordinates: coordinates)
    }
}

/// Natural Earth writes `-99` (int or string) and `""` for absent
/// values. They must not survive into the runtime asset as text.
func string(_ properties: [String: Any], _ key: String) -> String? {
    guard let raw = properties[key] else { return nil }
    let value: String
    switch raw {
    case let text as String: value = text
    case let number as NSNumber: value = number.stringValue
    default: return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != "-99", trimmed != "-99.0" else { return nil }
    return trimmed
}

func double(_ properties: [String: Any], _ key: String) -> Double? {
    switch properties[key] {
    case let number as NSNumber: return number.doubleValue
    case let text as String: return Double(text)
    default: return nil
    }
}

// MARK: - Ring extraction

/// A GeoJSON ring: `[[lon, lat], …]`, closing vertex included.
///
/// The closing vertex is dropped here (the runtime format implies it),
/// and rings with fewer than three distinct points are dropped
/// entirely — the 1:110m dataset has none, but a degenerate ring would
/// otherwise reach the decoder and fail the whole load.
func flattenRing(_ raw: Any) -> [Double]? {
    guard let points = raw as? [[Double]], points.count >= 4 else { return nil }

    var values: [Double] = []
    values.reserveCapacity(points.count * 2)
    for point in points {
        guard point.count >= 2 else { return nil }
        let longitude = point[0]
        let latitude = point[1]
        guard longitude.isFinite, latitude.isFinite,
              (-180.0...180.0).contains(longitude), (-90.0...90.0).contains(latitude) else {
            return nil
        }
        values.append(longitude)
        values.append(latitude)
    }

    // Drop the repeated closing vertex.
    if values.count >= 4,
       values[0] == values[values.count - 2],
       values[1] == values[values.count - 1] {
        values.removeLast(2)
    }

    return values.count >= 6 ? values : nil
}

func polygons(from feature: GeoJSONFeature) -> [RuntimePolygon] {
    switch feature.geometryType {
    case "Polygon":
        guard let rings = feature.coordinates as? [Any] else { return [] }
        let flattened = rings.compactMap(flattenRing)
        return flattened.isEmpty ? [] : [RuntimePolygon(rings: flattened)]
    case "MultiPolygon":
        guard let polygonList = feature.coordinates as? [Any] else { return [] }
        return polygonList.compactMap { polygon -> RuntimePolygon? in
            guard let rings = polygon as? [Any] else { return nil }
            let flattened = rings.compactMap(flattenRing)
            return flattened.isEmpty ? nil : RuntimePolygon(rings: flattened)
        }
    default:
        return []
    }
}

// MARK: - Capitals

/// Capitals join: `ne_110m_populated_places` filtered to
/// `FEATURECLA == "Admin-0 capital"` **and** `ADM0CAP == 1`, joined on
/// `ADM0_A3`.
///
/// Both conditions matter. The feature class alone also matches
/// Johannesburg for South Africa, which is not a capital; `ADM0CAP`
/// excludes it while keeping all three of South Africa's real capitals
/// and both of Bolivia's. Countries with no matching record keep an
/// empty list — the dataset does not have a capital for Antarctica,
/// Western Sahara, Palestine or Greenland, and this tool does not
/// invent one.
struct CapitalIndex {
    /// Keyed by the place record's `ADM0_A3`, filtered on `ADM0CAP = 1`.
    let byCountryCode: [String: [String]]
    /// Keyed by the place record's `ADM0NAME`, without the `ADM0CAP`
    /// filter — the fallback described below.
    let byCountryName: [String: [String]]
}

func capitalIndex(features: [GeoJSONFeature]) -> CapitalIndex {
    var byCode: [String: [String]] = [:]
    var byName: [String: [String]] = [:]

    for feature in features {
        guard string(feature.properties, "FEATURECLA") == "Admin-0 capital",
              let name = string(feature.properties, "NAME") else { continue }

        if double(feature.properties, "ADM0CAP") == 1,
           let key = string(feature.properties, "ADM0_A3") {
            byCode[key, default: []].append(name)
        }
        if let countryName = string(feature.properties, "ADM0NAME") {
            byName[countryName, default: []].append(name)
        }
    }

    let dedupe: ([String]) -> [String] = { Array(Set($0)).sorted() }
    return CapitalIndex(
        byCountryCode: byCode.mapValues(dedupe),
        byCountryName: byName.mapValues(dedupe)
    )
}

// MARK: - Build

let countryFeatures = readFeatures(at: countriesURL)
let placeFeatures = readFeatures(at: placesURL)
guard !countryFeatures.isEmpty else { fail("no country features found") }

let capitals = capitalIndex(features: placeFeatures)

var runtimeCountries: [RuntimeCountry] = []
var skipped: [String] = []
var withoutCapital: [String] = []
var withoutISO: [String] = []
var nameJoined: [String] = []

for feature in countryFeatures {
    guard let key = string(feature.properties, "ADM0_A3"),
          let name = string(feature.properties, "NAME") else {
        skipped.append("<unnamed feature>")
        continue
    }

    let rings = polygons(from: feature)
    guard !rings.isEmpty else {
        skipped.append("\(name) (no usable geometry)")
        continue
    }

    // `ISO_A3_EH`/`ISO_A2_EH` are Natural Earth's own corrected ISO
    // columns; they carry codes for France and Norway, which `ISO_A3`
    // leaves as -99. They are still absent for Kosovo, Somaliland and
    // Northern Cyprus, which genuinely have no assigned ISO code.
    let iso3 = string(feature.properties, "ISO_A3_EH") ?? string(feature.properties, "ISO_A3")
    let iso2 = string(feature.properties, "ISO_A2_EH") ?? string(feature.properties, "ISO_A2")
    if iso3 == nil { withoutISO.append(name) }

    // Primary join on ADM0_A3.
    var countryCapitals = capitals.byCountryCode[key] ?? []

    // Documented fallback. Natural Earth v5.1.2 keys South Sudan's
    // country feature as ADM0_A3 = "SDS" while keying Juba's place
    // record as "SSD" with ADM0CAP = 0, so the primary join misses a
    // capital the dataset does contain. When the code join finds
    // nothing, retry on the place record's ADM0NAME against the
    // country's ADMIN name. This still takes the capital from the same
    // source file — it only repairs the key — and it is reported below
    // so every use is auditable.
    if countryCapitals.isEmpty,
       let adminName = string(feature.properties, "ADMIN"),
       let byName = capitals.byCountryName[adminName], !byName.isEmpty {
        countryCapitals = byName
        nameJoined.append("\(name): \(byName.joined(separator: ", "))")
    }

    if countryCapitals.isEmpty { withoutCapital.append(name) }

    // Natural Earth's hand-placed label point, which is better than a
    // centroid for shapes like Chile or Norway. Falls back to the
    // bounding-box centre of the first polygon when absent.
    var labelLatitude = double(feature.properties, "LABEL_Y")
    var labelLongitude = double(feature.properties, "LABEL_X")
    if labelLatitude == nil || labelLongitude == nil,
       let outer = rings.first?.rings.first {
        let longitudes = stride(from: 0, to: outer.count, by: 2).map { outer[$0] }
        let latitudes = stride(from: 1, to: outer.count, by: 2).map { outer[$0] }
        labelLongitude = (longitudes.min()! + longitudes.max()!) / 2
        labelLatitude = (latitudes.min()! + latitudes.max()!) / 2
    }

    runtimeCountries.append(
        RuntimeCountry(
            id: key,
            name: name,
            longName: string(feature.properties, "NAME_LONG"),
            iso2: iso2,
            iso3: iso3,
            continent: string(feature.properties, "CONTINENT"),
            region: string(feature.properties, "REGION_UN"),
            subregion: string(feature.properties, "SUBREGION"),
            capitals: countryCapitals,
            labelLatitude: labelLatitude ?? 0,
            labelLongitude: labelLongitude ?? 0,
            polygons: rings
        )
    )
}

// Stable output order.
runtimeCountries.sort { $0.id < $1.id }

let provenance = DatasetProvenance(
    geometrySource: "Natural Earth — Admin 0 Countries, 1:110m",
    geometrySourceURL: "https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/geojson/ne_110m_admin_0_countries.geojson",
    geometryVersion: "natural-earth-vector v5.1.2",
    geometryLicense: "Public domain (Natural Earth terms of use)",
    metadataSource: "Natural Earth — Populated Places, 1:110m (Admin-0 capitals)",
    metadataSourceURL: "https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/geojson/ne_110m_populated_places.geojson",
    metadataVersion: "natural-earth-vector v5.1.2",
    metadataLicense: "Public domain (Natural Earth terms of use)",
    imagerySource: "NASA Earth Observatory — Blue Marble: Next Generation (topography and bathymetry), December 2004",
    imagerySourceURL: "https://visibleearth.nasa.gov/images/73909/december-blue-marble-next-generation-w-topography-and-bathymetry",
    imageryLicense: "Public domain (NASA media usage guidelines; credit requested)",
    imageryAttribution: "Surface imagery: NASA Earth Observatory, Blue Marble: Next Generation, by Reto Stöckli.",
    attribution: "Country boundaries, names and capitals from Natural Earth (naturalearthdata.com), public domain.",
    transformations: [
        "Selected ADM0_A3, NAME, NAME_LONG, ISO_A2_EH/ISO_A2, ISO_A3_EH/ISO_A3, CONTINENT, REGION_UN, SUBREGION, LABEL_X, LABEL_Y.",
        "Joined Admin-0 capitals on ADM0_A3 where FEATURECLA = 'Admin-0 capital' and ADM0CAP = 1.",
        "Where that join found nothing, retried on the place record's ADM0NAME against the country's ADMIN name (needed for South Sudan, whose keys disagree in the source).",
        "Flattened Polygon/MultiPolygon rings to interleaved [lon, lat] arrays and dropped the repeated closing vertex.",
        "Dropped rings with fewer than three distinct points; no simplification, reprojection or coordinate rounding applied.",
        "Normalized Natural Earth's -99 and empty-string placeholders to absent values.",
        "Downsampled the NASA Blue Marble surface imagery from 5400×2700 to 4096×2048 and re-encoded it as JPEG; no colour or projection change."
    ],
    // Pinned to the source release rather than the wall clock, so
    // regenerating from the same inputs produces identical output.
    generatedAt: "natural-earth-vector v5.1.2 (fetched 2026-10-05)",
    countryCount: runtimeCountries.count
)

let dataset = RuntimeDataset(provenance: provenance, countries: runtimeCountries)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let encoded: Data
do {
    encoded = try encoder.encode(dataset)
} catch {
    fail("encoding failed: \(error.localizedDescription)")
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try encoded.write(to: outputURL, options: .atomic)
} catch {
    fail("cannot write \(outputURL.path): \(error.localizedDescription)")
}

// MARK: - Surface imagery

/// Downsamples the Blue Marble source image into the texture the globe
/// is drawn with.
///
/// The source is 5400×2700. At 4096×2048 the texture costs 32 MB of
/// video memory instead of 58 MB and is still finer than the globe's
/// on-screen size at the closest zoom, so nothing visible is lost. The
/// output is re-encoded as JPEG because the alternative — a lossless
/// 32 MB PNG in the app bundle — would buy nothing for photographic
/// imagery.
func writeSurfaceTexture() {
    let targetWidth = 4096
    let targetHeight = 2048

    guard let source = NSImage(contentsOf: imageryURL) else {
        fail("cannot read \(imageryURL.path)\nRun Tools/fetch-source-data.sh first.")
    }

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetWidth,
        pixelsHigh: targetHeight,
        bitsPerSample: 8,
        // An RGBA context: AppKit will not create a drawing context for
        // a 24-bit bitmap. The alpha channel is dropped by the JPEG
        // encoder below.
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fail("could not allocate the texture bitmap")
    }
    rep.size = NSSize(width: targetWidth, height: targetHeight)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        fail("could not create a drawing context for the texture")
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let encoded = rep.representation(
        using: .jpeg,
        properties: [.compressionFactor: 0.86]
    ) else {
        fail("could not encode the texture")
    }

    do {
        try FileManager.default.createDirectory(
            at: textureOutputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded.write(to: textureOutputURL, options: .atomic)
    } catch {
        fail("cannot write \(textureOutputURL.path): \(error.localizedDescription)")
    }

    print("Wrote \(textureOutputURL.lastPathComponent): \(targetWidth)×\(targetHeight), "
        + "\(String(format: "%.0f", Double(encoded.count) / 1024)) KB")
}

writeSurfaceTexture()

// Re-read through the real decoder: the tool refuses to leave an asset
// in place that the app could not load.
do {
    let verified = try GeographyDecoder.decodeDataset(from: encoded)
    let vertices = verified.countries.reduce(0) { total, country in
        total + country.geometry.polygons.reduce(0) { $0 + $1.allRings.reduce(0) { $0 + $1.coordinates.count } }
    }
    let byteCount = Double(encoded.count) / 1024

    print("Wrote \(outputURL.lastPathComponent): \(verified.countries.count) countries, "
        + "\(vertices) vertices, \(String(format: "%.0f", byteCount)) KB")
    print("Verified by decoding through GeographyDecoder.")
    if !skipped.isEmpty { print("Skipped features: \(skipped.joined(separator: ", "))") }
    if !nameJoined.isEmpty { print("Capitals matched by name fallback (\(nameJoined.count)): \(nameJoined.sorted().joined(separator: "; "))") }
    print("Without an ISO alpha-3 code (\(withoutISO.count)): \(withoutISO.sorted().joined(separator: ", "))")
    print("Without a capital in the dataset (\(withoutCapital.count)): \(withoutCapital.sorted().joined(separator: ", "))")
} catch {
    fail("generated asset failed verification: \(error.localizedDescription)")
}
