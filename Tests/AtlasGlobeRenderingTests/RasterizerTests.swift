import Foundation
import Testing
@testable import AtlasGlobeRendering
import AtlasDesktopCore

struct EquirectangularRasterizerTests {
    private func ring(_ points: [(Double, Double)]) throws -> GeoRing {
        try GeoRing(coordinates: points.map { try Coordinate(latitude: $0.0, longitude: $0.1) })
    }

    private func country(
        id: String,
        name: String,
        corners: [(Double, Double)],
        holes: [[(Double, Double)]] = []
    ) throws -> Country {
        Country(
            facts: CountryFacts(id: CountryID(rawValue: id)!, name: name),
            geometry: try CountryGeometry(polygons: [
                GeoPolygon(
                    outerRing: try ring(corners),
                    holes: try holes.map { try ring($0) }
                )
            ]),
            labelAnchor: try Coordinate(
                latitude: corners.map(\.0).reduce(0, +) / Double(corners.count),
                longitude: corners.map(\.1).reduce(0, +) / Double(corners.count)
            )
        )
    }

    @Test func fillsAPolygonAndLeavesTheRestAsOcean() throws {
        let big = try country(id: "BIG", name: "Bigland", corners: [(0, 0), (0, 40), (40, 40), (40, 0)])
        let map = EquirectangularRasterizer.rasterize(countries: [big], width: 360, height: 180)

        #expect(map.countryID(at: try Coordinate(latitude: 20, longitude: 20))?.rawValue == "BIG")
        #expect(map.countryID(at: try Coordinate(latitude: -20, longitude: 20)) == nil)
        #expect(map.countryID(at: try Coordinate(latitude: 20, longitude: -20)) == nil)
    }

    /// Even-odd filling across the outer ring and its holes together is
    /// what makes an enclave come out as a hole with no special case.
    @Test func holesAreNotFilled() throws {
        let donut = try country(
            id: "DON", name: "Donutia",
            corners: [(0, 0), (0, 40), (40, 40), (40, 0)],
            holes: [[(15, 15), (15, 25), (25, 25), (25, 15)]]
        )
        let map = EquirectangularRasterizer.rasterize(countries: [donut], width: 720, height: 360)

        #expect(map.countryID(at: try Coordinate(latitude: 5, longitude: 5))?.rawValue == "DON")
        #expect(map.countryID(at: try Coordinate(latitude: 20, longitude: 20)) == nil)
    }

    /// Smaller countries are drawn last so an enclave wins where the
    /// source geometry overlaps — the same rule `CountryLookup` uses, so
    /// what is drawn and what is clicked agree.
    @Test func smallerCountriesAreDrawnOnTop() throws {
        let big = try country(id: "BIG", name: "Bigland", corners: [(0, 0), (0, 40), (40, 40), (40, 0)])
        let small = try country(id: "SML", name: "Smallia", corners: [(18, 18), (18, 22), (22, 22), (22, 18)])
        let map = EquirectangularRasterizer.rasterize(countries: [big, small], width: 720, height: 360)

        #expect(map.countryID(at: try Coordinate(latitude: 20, longitude: 20))?.rawValue == "SML")
        #expect(map.countryID(at: try Coordinate(latitude: 5, longitude: 5))?.rawValue == "BIG")
    }

    /// A country smaller than one raster cell must still appear, or its
    /// border would be drawn around an empty patch of ocean.
    @Test func aCountrySmallerThanOneCellStillGetsAPixel() throws {
        let tiny = try country(
            id: "TNY", name: "Tinystan",
            corners: [(10.0, 10.0), (10.0, 10.02), (10.02, 10.02), (10.02, 10.0)]
        )
        let map = EquirectangularRasterizer.rasterize(countries: [tiny], width: 360, height: 180)
        #expect(map.indices.contains { $0 != 0 })
    }

    @Test func pixelMappingPutsTheOriginAtTheCentreOfTheImage() {
        let map = CountryIndexMap(width: 360, height: 180, indices: [], countryIDs: [])
        let centre = map.pixel(for: try! Coordinate(latitude: 0, longitude: 0))
        #expect(centre == (180, 90))

        let topLeft = map.pixel(for: try! Coordinate(latitude: 90, longitude: -180))
        #expect(topLeft == (0, 0))

        // The far corner clamps inside the image rather than overflowing.
        let bottomRight = map.pixel(for: try! Coordinate(latitude: -90, longitude: 180))
        #expect(bottomRight == (359, 179))
    }

    @Test func indexMapIgnoresValuesItHasNoCountryFor() {
        let map = CountryIndexMap(
            width: 2, height: 1,
            indices: [0, 7],
            countryIDs: [CountryID(rawValue: "AAA")!]
        )
        #expect(map.countryID(at: try! Coordinate(latitude: 0, longitude: 90)) == nil)
    }
}

struct GlobeTextureFactoryTests {
    private var map: CountryIndexMap {
        CountryIndexMap(
            width: 4, height: 2,
            indices: [0, 1, 1, 0, 0, 2, 0, 0],
            countryIDs: [CountryID(rawValue: "AAA")!, CountryID(rawValue: "BBB")!]
        )
    }

    @Test func baseTextureMatchesTheIndexMapDimensions() throws {
        let image = try #require(GlobeTextureFactory.baseTexture(from: map))
        #expect(image.width == 4)
        #expect(image.height == 2)
    }

    @Test func selectionOverlayIsBuiltOnlyForACountryThatIsPresent() throws {
        #expect(GlobeTextureFactory.selectionOverlay(from: map, selected: nil) == nil)
        #expect(GlobeTextureFactory.selectionOverlay(from: map, selected: CountryID(rawValue: "ZZZ")!) == nil)
        #expect(GlobeTextureFactory.selectionOverlay(from: map, selected: CountryID(rawValue: "AAA")!) != nil)
    }

    @Test func starFieldIsDeterministic() throws {
        let first = try #require(GlobeTextureFactory.starField(width: 64, height: 32, starCount: 50))
        let second = try #require(GlobeTextureFactory.starField(width: 64, height: 32, starCount: 50))
        #expect(first.dataProvider?.data == second.dataProvider?.data)
    }

    @Test func atmosphereGradientIsTransparentAtTheCentreAndAtTheEdge() throws {
        let image = try #require(GlobeTextureFactory.atmosphereGradient(size: 64, limbRadius: 0.87))
        let data = try #require(image.dataProvider?.data as Data?)

        func alpha(x: Int, y: Int) -> UInt8 { data[(y * 64 + x) * 4 + 3] }

        // Clear over the globe itself and at the very edge of the quad,
        // bright in the band at the limb.
        #expect(alpha(x: 32, y: 32) == 0)
        #expect(alpha(x: 0, y: 0) == 0)
        #expect(alpha(x: 32, y: 32 - Int(0.87 * 32)) > 40)
    }
}
