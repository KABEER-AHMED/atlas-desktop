import Foundation
import Testing
@testable import AtlasGeographyData
import AtlasDesktopCore

/// Tests against the asset that actually ships.
///
/// These are integration tests: they read the bundled file, decode it
/// through the real repository, and assert facts about real countries.
/// Nothing here touches the network — which is the point, since offline
/// operation is a release requirement.
@Suite struct BundledGeographyTests {
    /// Decoded synchronously from the same bundled file the repository
    /// reads. It is deliberately *not* loaded through the repository's
    /// async API here: blocking on an async task inside a lazy global
    /// initializer deadlocks, because the runtime's one-time
    /// initialization lock is held while the task waits to be scheduled.
    /// `repositoryLoadsTheBundledAsset` covers the async path.
    static let dataset: GeographyDataset = {
        let bundle = BundledGeographyRepository.resourceBundle
        guard let url = bundle.url(
            forResource: BundledGeographyRepository.resourceName,
            withExtension: BundledGeographyRepository.resourceExtension
        ) else {
            fatalError("the bundled geography asset is missing from the test bundle")
        }
        do {
            return try GeographyDecoder.decodeDataset(from: try Data(contentsOf: url))
        } catch {
            // A failure here means the app itself could not start.
            fatalError("the bundled geography asset did not decode: \(error)")
        }
    }()

    private var dataset: GeographyDataset { Self.dataset }

    private func country(_ id: String) throws -> Country {
        let identifier = try #require(CountryID(rawValue: id))
        return try #require(dataset.lookup.country(id: identifier), "no country with id \(id)")
    }

    @Test func bundledDatasetLoadsEveryCountry() {
        #expect(dataset.countries.count == 177)
        #expect(dataset.provenance.countryCount == dataset.countries.count)
    }

    @Test func provenanceNamesItsSourcesAndLicences() {
        let provenance = dataset.provenance
        #expect(provenance.geometryVersion.contains("v5.1.2"))
        #expect(provenance.geometryLicense.lowercased().contains("public domain"))
        #expect(provenance.metadataLicense.lowercased().contains("public domain"))
        #expect(provenance.imageryLicense.lowercased().contains("public domain"))
        #expect(!provenance.attribution.isEmpty)
        #expect(!provenance.transformations.isEmpty)
    }

    @Test func identifiersAreUnique() {
        #expect(Set(dataset.countries.map(\.id)).count == dataset.countries.count)
    }

    // MARK: - Representative facts

    @Test func franceHasItsFactsIncludingAnISOCodeNaturalEarthOmits() throws {
        let france = try country("FRA")
        #expect(france.facts.name == "France")
        #expect(france.facts.capitals == ["Paris"])
        #expect(france.facts.continent == "Europe")
        // ISO_A3 is -99 for France in this release; ISO_A3_EH carries it.
        #expect(france.facts.isoAlpha3 == "FRA")
        #expect(france.facts.isoAlpha2 == "FR")
    }

    /// South Africa genuinely has three capitals, and Johannesburg is
    /// not one of them — the ADM0CAP filter in the generator exists for
    /// exactly this record.
    @Test func southAfricaHasAllThreeCapitalsAndNoImposters() throws {
        let southAfrica = try country("ZAF")
        #expect(southAfrica.facts.capitals == ["Bloemfontein", "Cape Town", "Pretoria"])
        #expect(!southAfrica.facts.capitals.contains("Johannesburg"))
    }

    @Test func boliviaHasBothOfItsCapitals() throws {
        #expect(try country("BOL").facts.capitals == ["La Paz", "Sucre"])
    }

    /// The source keys South Sudan's country and its capital
    /// differently; the generator's documented name fallback repairs it.
    @Test func southSudanGetsItsCapitalThroughTheNameFallback() throws {
        #expect(try country("SDS").facts.capitals == ["Juba"])
    }

    /// Missing facts stay missing. These are real gaps in the dataset,
    /// not bugs, and the app must not invent values for them.
    @Test(arguments: ["ATA", "GRL", "ESH", "PSX"])
    func countriesWithNoCapitalInTheDatasetHaveNone(id: String) throws {
        // Western Sahara is keyed SAH in this release.
        let identifier = id == "ESH" ? "SAH" : id
        #expect(try country(identifier).facts.capitals.isEmpty)
    }

    @Test(arguments: ["KOS", "SOL", "CYN"])
    func territoriesWithoutAnAssignedISOCodeAreMarkedAsSuch(id: String) throws {
        let facts = try country(id).facts
        #expect(facts.isoAlpha3 == nil)
        #expect(!facts.hasISOIdentifier)
        #expect(facts.displayIdentifier == id)
    }

    @Test func everyCountryHasANameAndUsableGeometry() throws {
        for country in dataset.countries {
            #expect(!country.facts.name.isEmpty)
            #expect(!country.geometry.polygons.isEmpty)
            #expect(country.geometry.relativeSize > 0)
        }
    }

    // MARK: - Geographic edge cases

    /// Fiji and Russia straddle the 180th meridian. Their geometry must
    /// survive decoding, and their outlines must be split before they
    /// are drawn.
    @Test(arguments: ["FJI", "RUS", "NZL"])
    func countriesOnTheAntimeridianDecodeAndSplit(id: String) throws {
        let subject = try country(id)
        #expect(subject.geometry.polygons.count > 1)

        let wrapping = subject.geometry.polygons.flatMap(\.allRings).filter {
            Antimeridian.crossesAntimeridian(path: $0.closedCoordinates)
        }
        for ring in wrapping {
            #expect(Antimeridian.split(path: ring.closedCoordinates).count > 1)
        }
    }

    @Test func multiPolygonCountriesKeepAllTheirParts() throws {
        #expect(try country("IDN").geometry.polygons.count > 5)
        #expect(try country("JPN").geometry.polygons.count > 1)
    }

    /// An enclave must be selectable: clicking Lesotho has to give
    /// Lesotho, not South Africa around it.
    @Test func enclavesAreSelectable() throws {
        let lesotho = try country("LSO")
        let hit = dataset.lookup.country(at: lesotho.labelAnchor)
        #expect(hit?.id == lesotho.id)
    }

    @Test(arguments: [
        (48.86, 2.35, "FRA"), (35.68, 139.69, "JPN"), (-33.87, 151.21, "AUS"),
        (64.13, -21.90, "ISL"), (-1.29, 36.82, "KEN"), (19.43, -99.13, "MEX"),
        (61.22, -149.90, "USA"), (55.75, 37.62, "RUS")
    ])
    func citiesResolveToTheirCountries(latitude: Double, longitude: Double, expected: String) throws {
        let coordinate = try Coordinate(latitude: latitude, longitude: longitude)
        let hit = try #require(dataset.lookup.country(at: coordinate))
        #expect(hit.id.rawValue == expected)
    }

    /// Antarctica's main polygon closes across the pole: it runs along
    /// latitude -90 from longitude 180 to -180. Interior points must
    /// still resolve, which is what proves the point-in-polygon test
    /// copes with a polygon that spans the entire longitude range.
    ///
    /// Coastal stations are deliberately not used here. At 1:110m the
    /// coastline is simplified by tens of kilometres, so McMurdo and
    /// Davis both fall marginally outside it — a property of the
    /// dataset's scale, not of the lookup. See docs/DATA_AND_LICENSES.md.
    @Test(arguments: [(-89.9, 0.0), (-78.46, 106.84), (-85.0, -100.0), (-75.0, 120.0), (-80.0, 160.0)])
    func antarcticInteriorPointsResolveAcrossThePole(latitude: Double, longitude: Double) throws {
        let coordinate = try Coordinate(latitude: latitude, longitude: longitude)
        #expect(dataset.lookup.country(at: coordinate)?.id.rawValue == "ATA")
    }

    @Test(arguments: [(0.0, -150.0), (-40.0, -30.0), (20.0, -40.0)])
    func openOceanResolvesToNothing(latitude: Double, longitude: Double) throws {
        #expect(dataset.lookup.country(at: try Coordinate(latitude: latitude, longitude: longitude)) == nil)
    }

    @Test func labelAnchorsSitInsideTheirOwnCountryForLargeCountries() throws {
        // Natural Earth's label points are hand-placed; for countries of
        // any size they should land on the country itself.
        for country in dataset.countries where country.geometry.relativeSize > 50 {
            #expect(
                country.geometry.containsPoint(country.labelAnchor),
                "\(country.facts.name)'s label anchor is outside its geometry"
            )
        }
    }

    // MARK: - Search

    @Test func searchFindsCountriesByNameAndCode() throws {
        #expect(dataset.lookup.search("japan").first?.id.rawValue == "JPN")
        #expect(dataset.lookup.search("JPN").first?.id.rawValue == "JPN")
        #expect(dataset.lookup.search("  ").count == dataset.countries.count)
        #expect(dataset.lookup.search("zzzznotacountry").isEmpty)
    }

    // MARK: - Failure handling

    /// The async path the app actually uses.
    @Test func repositoryLoadsTheBundledAsset() async throws {
        let loaded = try await BundledGeographyRepository().load()
        #expect(loaded.countries.count == dataset.countries.count)
    }

    @Test func aMissingResourceReportsItselfProperly() async {
        // An empty bundle stands in for a damaged installation.
        let repository = BundledGeographyRepository(bundle: Bundle(for: EmptyBundleMarker.self))
        await #expect(throws: (any Error).self) {
            try await repository.load()
        }
    }
}

/// Only used to get at a bundle that certainly has no geography data.
private final class EmptyBundleMarker {}
