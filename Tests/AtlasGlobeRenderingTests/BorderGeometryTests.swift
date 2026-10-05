import Foundation
import Testing
@testable import AtlasGlobeRendering
import AtlasDesktopCore

struct BorderGeometryTests {
    private func path(_ points: [(Double, Double)]) throws -> [Coordinate] {
        try points.map { try Coordinate(latitude: $0.0, longitude: $0.1) }
    }

    /// Source vertices can be several degrees apart. A straight 3D
    /// segment between two such points cuts visibly through the sphere,
    /// so long segments are subdivided before projection.
    @Test func longSegmentsAreSubdivided() throws {
        let densified = BorderGeometry.densify(path: try path([(0, 0), (0, 30)]))
        #expect(densified.count > 20)
        #expect(densified.first?.longitude == 0)
        #expect(densified.last?.longitude == 30)
    }

    @Test func shortSegmentsAreLeftAlone() throws {
        let original = try path([(0, 0), (0.5, 0.5), (1, 1)])
        #expect(BorderGeometry.densify(path: original) == original)
    }

    /// Longitude degrees shrink toward the poles, so a step that needs
    /// subdividing at the equator may not need it at high latitude.
    @Test func subdivisionAccountsForConvergingMeridians() throws {
        let equatorial = BorderGeometry.densify(path: try path([(0, 0), (0, 10)]))
        let polar = BorderGeometry.densify(path: try path([(85, 0), (85, 10)]))
        #expect(polar.count < equatorial.count)
    }

    @Test func densifiedPointsStayOnThePathBetweenTheirEndpoints() throws {
        let densified = BorderGeometry.densify(path: try path([(10, 20), (20, 40)]))
        for point in densified {
            #expect(point.latitude >= 10 && point.latitude <= 20)
            #expect(point.longitude >= 20 && point.longitude <= 40)
        }
    }

    @Test func singlePointPathsAreReturnedUnchanged() throws {
        let single = try path([(5, 5)])
        #expect(BorderGeometry.densify(path: single) == single)
        #expect(BorderGeometry.densify(path: []).isEmpty)
    }

    @Test func buildsLineGeometryForACountry() throws {
        let country = Country(
            facts: CountryFacts(id: CountryID(rawValue: "TST")!, name: "Testland"),
            geometry: try CountryGeometry(polygons: [
                GeoPolygon(outerRing: try GeoRing(coordinates: try path([(0, 0), (0, 10), (10, 10), (10, 0)])))
            ]),
            labelAnchor: try Coordinate(latitude: 5, longitude: 5)
        )

        let geometry = try #require(
            BorderGeometry.outlineGeometry(for: [country], radius: 1.003, color: .white)
        )
        #expect(geometry.elements.first?.primitiveType == .line)
        #expect((geometry.elements.first?.primitiveCount ?? 0) > 0)
    }

    @Test func buildsNothingFromNoCountries() {
        #expect(BorderGeometry.outlineGeometry(for: [], radius: 1, color: .white) == nil)
    }
}
