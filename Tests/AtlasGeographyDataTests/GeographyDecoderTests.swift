import Foundation
import Testing
@testable import AtlasGeographyData
import AtlasDesktopCore

/// Decoder tests work from hand-built payloads rather than the bundled
/// asset, so malformed input can be exercised deliberately. The bundled
/// asset is covered separately in `BundledGeographyTests`.
struct GeographyDecoderTests {
    private static let provenance = DatasetProvenance(
        geometrySource: "fixture", geometrySourceURL: "", geometryVersion: "1",
        geometryLicense: "n/a", metadataSource: "fixture", metadataSourceURL: "",
        metadataVersion: "1", metadataLicense: "n/a",
        imagerySource: "fixture", imagerySourceURL: "", imageryLicense: "n/a",
        imageryAttribution: "", attribution: "fixture",
        transformations: [], generatedAt: "test", countryCount: 1
    )

    /// A unit square at the origin, as interleaved [lon, lat] values.
    private static let square: [Double] = [0, 0, 10, 0, 10, 10, 0, 10]

    private func payload(
        formatVersion: Int = RuntimeDataset.supportedFormatVersion,
        countries: [RuntimeCountry]
    ) throws -> Data {
        try JSONEncoder().encode(
            RuntimeDataset(
                formatVersion: formatVersion,
                provenance: Self.provenance,
                countries: countries
            )
        )
    }

    private func country(
        id: String = "TST",
        name: String = "Testland",
        longName: String? = nil,
        iso2: String? = "TS",
        iso3: String? = "TST",
        capitals: [String] = ["Test City"],
        labelLatitude: Double = 5,
        labelLongitude: Double = 5,
        polygons: [RuntimePolygon]? = nil
    ) -> RuntimeCountry {
        RuntimeCountry(
            id: id, name: name, longName: longName, iso2: iso2, iso3: iso3,
            continent: "Testia", region: "Testia", subregion: "North Testia",
            capitals: capitals,
            labelLatitude: labelLatitude, labelLongitude: labelLongitude,
            polygons: polygons ?? [RuntimePolygon(rings: [Self.square])]
        )
    }

    @Test func decodesAValidDataset() throws {
        let dataset = try GeographyDecoder.decodeDataset(from: try payload(countries: [country()]))
        #expect(dataset.countries.count == 1)

        let decoded = try #require(dataset.countries.first)
        #expect(decoded.facts.name == "Testland")
        #expect(decoded.facts.capitals == ["Test City"])
        #expect(decoded.geometry.polygons.count == 1)
        #expect(decoded.labelAnchor.latitude == 5)
    }

    @Test func decodesHolesAsHoles() throws {
        let hole: [Double] = [3, 3, 7, 3, 7, 7, 3, 7]
        let dataset = try GeographyDecoder.decodeDataset(
            from: try payload(countries: [
                country(polygons: [RuntimePolygon(rings: [Self.square, hole])])
            ])
        )
        let geometry = try #require(dataset.countries.first?.geometry)
        #expect(geometry.polygons[0].holes.count == 1)
        #expect(!geometry.containsPoint(try Coordinate(latitude: 5, longitude: 5)))
        #expect(geometry.containsPoint(try Coordinate(latitude: 1, longitude: 1)))
    }

    /// Natural Earth's "no value" placeholders must not reach the UI as
    /// a displayed "-99".
    @Test func normalizesPlaceholdersToAbsentValues() throws {
        let dataset = try GeographyDecoder.decodeDataset(
            from: try payload(countries: [country(iso2: "-99", iso3: "  ", capitals: ["-99", "Real City"])])
        )
        let facts = try #require(dataset.countries.first?.facts)
        #expect(facts.isoAlpha2 == nil)
        #expect(facts.isoAlpha3 == nil)
        #expect(facts.capitals == ["Real City"])
        #expect(!facts.hasISOIdentifier)
        // With no ISO code, the dataset's own key is what gets shown.
        #expect(facts.displayIdentifier == "TST")
    }

    @Test func dropsALongNameThatOnlyRepeatsTheShortName() throws {
        let dataset = try GeographyDecoder.decodeDataset(
            from: try payload(countries: [country(longName: "Testland")])
        )
        #expect(dataset.countries.first?.facts.longName == nil)
    }

    @Test func fallsBackToTheBoundingBoxCentreForABadLabelAnchor() throws {
        let dataset = try GeographyDecoder.decodeDataset(
            from: try payload(countries: [country(labelLatitude: 999, labelLongitude: 999)])
        )
        let anchor = try #require(dataset.countries.first?.labelAnchor)
        #expect(anchor.latitude == 5)
        #expect(anchor.longitude == 5)
    }

    // MARK: - Failure cases

    @Test func rejectsAnUnsupportedFormatVersion() throws {
        let data = try payload(formatVersion: 99, countries: [country()])
        #expect(throws: GeographyError.unsupportedFormatVersion(found: 99, supported: 1)) {
            try GeographyDecoder.decodeDataset(from: data)
        }
    }

    @Test func rejectsAnEmptyDataset() throws {
        let data = try payload(countries: [])
        #expect(throws: GeographyError.emptyDataset) {
            try GeographyDecoder.decodeDataset(from: data)
        }
    }

    @Test func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            try GeographyDecoder.decodeDataset(from: Data("not json at all".utf8))
        }
    }

    @Test func rejectsAnInvalidIdentifier() throws {
        let data = try payload(countries: [country(id: "TOOLONG")])
        #expect(throws: (any Error).self) { try GeographyDecoder.decodeDataset(from: data) }
    }

    /// Truncated coordinate data must name the country it came from, so
    /// the error is actionable rather than "malformed data".
    @Test func rejectsAnOddNumberOfCoordinateValues() throws {
        let data = try payload(countries: [
            country(polygons: [RuntimePolygon(rings: [[0, 0, 10, 0, 10]])])
        ])
        do {
            _ = try GeographyDecoder.decodeDataset(from: data)
            Issue.record("expected the decoder to reject an odd coordinate count")
        } catch let error as GeographyError {
            #expect(error.failureReason?.contains("Testland") == true)
        }
    }

    @Test func rejectsOutOfRangeCoordinates() throws {
        let data = try payload(countries: [
            country(polygons: [RuntimePolygon(rings: [[0, 0, 10, 0, 500, 95]])])
        ])
        do {
            _ = try GeographyDecoder.decodeDataset(from: data)
            Issue.record("expected the decoder to reject an out-of-range coordinate")
        } catch let error as GeographyError {
            #expect(error.failureReason?.contains("out-of-range") == true)
        }
    }

    @Test func rejectsADegenerateRing() throws {
        let data = try payload(countries: [
            country(polygons: [RuntimePolygon(rings: [[0, 0, 1, 1, 0, 0]])])
        ])
        #expect(throws: (any Error).self) { try GeographyDecoder.decodeDataset(from: data) }
    }

    @Test func rejectsACountryWithNoGeometry() throws {
        let data = try payload(countries: [country(polygons: [])])
        #expect(throws: (any Error).self) { try GeographyDecoder.decodeDataset(from: data) }
    }

    @Test func everyErrorExplainsItselfAndHowToRecover() {
        let errors: [GeographyError] = [
            .resourceMissing(name: "atlas-countries.json"),
            .resourceUnreadable(name: "atlas-countries.json", reason: "permission denied"),
            .malformedData(reason: "truncated"),
            .unsupportedFormatVersion(found: 2, supported: 1),
            .emptyDataset
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.recoverySuggestion?.isEmpty == false)
        }
    }
}
