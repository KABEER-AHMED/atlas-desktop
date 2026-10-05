import Foundation
import AtlasDesktopCore

/// Turns the runtime asset into validated domain objects.
///
/// Validation is strict on purpose: every coordinate goes through
/// `Coordinate`'s range check and every ring through `GeoRing`'s
/// degenerate-ring check, so a truncated or corrupted asset produces a
/// `GeographyError` naming the offending country instead of a globe
/// with a stray triangle across it.
public enum GeographyDecoder {
    public static func decodeDataset(from data: Data) throws -> GeographyDataset {
        let runtime: RuntimeDataset
        do {
            runtime = try JSONDecoder().decode(RuntimeDataset.self, from: data)
        } catch {
            throw GeographyError.malformedData(reason: "JSON decoding failed: \(error.localizedDescription)")
        }

        guard runtime.formatVersion == RuntimeDataset.supportedFormatVersion else {
            throw GeographyError.unsupportedFormatVersion(
                found: runtime.formatVersion,
                supported: RuntimeDataset.supportedFormatVersion
            )
        }

        let countries = try runtime.countries.map(country(from:))
        guard !countries.isEmpty else { throw GeographyError.emptyDataset }

        return GeographyDataset(countries: countries, provenance: runtime.provenance)
    }

    public static func country(from runtime: RuntimeCountry) throws -> Country {
        guard let id = CountryID(rawValue: runtime.id) else {
            throw GeographyError.malformedData(reason: "Invalid country identifier “\(runtime.id)”")
        }

        guard !runtime.polygons.isEmpty else {
            throw GeographyError.malformedData(reason: "\(runtime.name) (\(runtime.id)) has no polygons")
        }

        var polygons: [GeoPolygon] = []
        polygons.reserveCapacity(runtime.polygons.count)

        for polygon in runtime.polygons {
            guard let outerValues = polygon.rings.first else {
                throw GeographyError.malformedData(reason: "\(runtime.name) (\(runtime.id)) has a polygon with no rings")
            }
            let outer = try ring(from: outerValues, country: runtime)
            let holes = try polygon.rings.dropFirst().map { try ring(from: $0, country: runtime) }
            polygons.append(GeoPolygon(outerRing: outer, holes: holes))
        }

        let geometry: CountryGeometry
        do {
            geometry = try CountryGeometry(polygons: polygons)
        } catch {
            throw GeographyError.malformedData(reason: "\(runtime.name) (\(runtime.id)) has unusable geometry")
        }

        let anchor = try labelAnchor(for: runtime, geometry: geometry)

        let facts = CountryFacts(
            id: id,
            name: runtime.name,
            longName: normalized(runtime.longName, differentFrom: runtime.name),
            isoAlpha2: normalized(runtime.iso2),
            isoAlpha3: normalized(runtime.iso3),
            continent: normalized(runtime.continent),
            region: normalized(runtime.region),
            subregion: normalized(runtime.subregion),
            capitals: runtime.capitals.compactMap { normalized($0) }
        )

        return Country(facts: facts, geometry: geometry, labelAnchor: anchor)
    }

    private static func ring(from values: [Double], country: RuntimeCountry) throws -> GeoRing {
        guard values.count >= 6, values.count % 2 == 0 else {
            throw GeographyError.malformedData(
                reason: "\(country.name) (\(country.id)) has a ring with \(values.count) coordinate values"
            )
        }

        var coordinates: [Coordinate] = []
        coordinates.reserveCapacity(values.count / 2)
        for index in stride(from: 0, to: values.count, by: 2) {
            do {
                coordinates.append(try Coordinate(latitude: values[index + 1], longitude: values[index]))
            } catch {
                throw GeographyError.malformedData(
                    reason: "\(country.name) (\(country.id)) has an out-of-range coordinate "
                        + "(\(values[index + 1]), \(values[index]))"
                )
            }
        }

        do {
            return try GeoRing(coordinates: coordinates)
        } catch {
            throw GeographyError.malformedData(
                reason: "\(country.name) (\(country.id)) has a degenerate ring of \(coordinates.count) points"
            )
        }
    }

    /// The dataset's own label point when it is usable, otherwise the
    /// centre of the largest polygon's bounding box.
    private static func labelAnchor(for runtime: RuntimeCountry, geometry: CountryGeometry) throws -> Coordinate {
        if let anchor = try? Coordinate(latitude: runtime.labelLatitude, longitude: runtime.labelLongitude) {
            return anchor
        }
        let box = (geometry.largestPolygon ?? geometry.polygons[0]).boundingBox
        guard let fallback = try? Coordinate(
            latitude: (box.minLatitude + box.maxLatitude) / 2,
            longitude: (box.minLongitude + box.maxLongitude) / 2
        ) else {
            throw GeographyError.malformedData(reason: "\(runtime.name) (\(runtime.id)) has no usable label anchor")
        }
        return fallback
    }

    /// Natural Earth uses `-99` and empty strings for "no value". They
    /// must stay absent rather than become a displayed "-99".
    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed != "-99" else { return nil }
        return trimmed
    }

    private static func normalized(_ value: String?, differentFrom other: String) -> String? {
        guard let normalizedValue = normalized(value), normalizedValue != other else { return nil }
        return normalizedValue
    }
}
