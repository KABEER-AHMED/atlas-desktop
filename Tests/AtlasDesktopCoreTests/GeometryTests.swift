import Testing
@testable import AtlasDesktopCore

struct GeoRingTests {
    private func ring(_ points: [(Double, Double)]) throws -> GeoRing {
        try GeoRing(coordinates: points.map { try Coordinate(latitude: $0.0, longitude: $0.1) })
    }

    /// GeoJSON repeats the first vertex to close a ring; the domain
    /// model stores it once and closes it implicitly.
    @Test func dropsTheRepeatedClosingVertex() throws {
        let square = try ring([(0, 0), (0, 10), (10, 10), (10, 0), (0, 0)])
        #expect(square.coordinates.count == 4)
        #expect(square.closedCoordinates.count == 5)
        #expect(square.closedCoordinates.first == square.closedCoordinates.last)
    }

    @Test func rejectsDegenerateRings() {
        #expect(throws: (any Error).self) {
            try GeoRing(coordinates: [
                try Coordinate(latitude: 0, longitude: 0),
                try Coordinate(latitude: 1, longitude: 1),
                try Coordinate(latitude: 0, longitude: 0)
            ])
        }
        #expect(throws: (any Error).self) { try GeoRing(coordinates: []) }
    }

    @Test func containsPointUsesEvenOddCrossing() throws {
        let square = try ring([(0, 0), (0, 10), (10, 10), (10, 0)])
        #expect(square.containsPoint(try Coordinate(latitude: 5, longitude: 5)))
        #expect(!square.containsPoint(try Coordinate(latitude: 5, longitude: 15)))
        #expect(!square.containsPoint(try Coordinate(latitude: 15, longitude: 5)))
    }

    @Test func boundingBoxCoversEveryVertex() throws {
        let shape = try ring([(-10, -20), (30, 5), (12, 44)])
        let box = shape.boundingBox
        #expect(box.minLatitude == -10)
        #expect(box.maxLatitude == 30)
        #expect(box.minLongitude == -20)
        #expect(box.maxLongitude == 44)
    }

    @Test func areaMagnitudeIsIndependentOfWindingDirection() throws {
        let clockwise = try ring([(0, 0), (10, 0), (10, 10), (0, 10)])
        let counterClockwise = try ring([(0, 10), (10, 10), (10, 0), (0, 0)])
        #expect(abs(abs(clockwise.signedPlanarArea) - abs(counterClockwise.signedPlanarArea)) < 1e-9)
        #expect(abs(abs(clockwise.signedPlanarArea) - 100) < 1e-9)
    }
}

struct GeoPolygonTests {
    private func ring(_ points: [(Double, Double)]) throws -> GeoRing {
        try GeoRing(coordinates: points.map { try Coordinate(latitude: $0.0, longitude: $0.1) })
    }

    /// An enclave: a point inside the hole is outside the polygon. This
    /// is the Lesotho-in-South-Africa case.
    @Test func holesAreNotPartOfThePolygon() throws {
        let polygon = GeoPolygon(
            outerRing: try ring([(0, 0), (0, 20), (20, 20), (20, 0)]),
            holes: [try ring([(8, 8), (8, 12), (12, 12), (12, 8)])]
        )
        #expect(polygon.containsPoint(try Coordinate(latitude: 4, longitude: 4)))
        #expect(!polygon.containsPoint(try Coordinate(latitude: 10, longitude: 10)))
    }

    @Test func multiPolygonGeometryCoversEveryPart() throws {
        let geometry = try CountryGeometry(polygons: [
            GeoPolygon(outerRing: try ring([(0, 0), (0, 5), (5, 5), (5, 0)])),
            GeoPolygon(outerRing: try ring([(40, 40), (40, 45), (45, 45), (45, 40)]))
        ])

        #expect(geometry.containsPoint(try Coordinate(latitude: 2, longitude: 2)))
        #expect(geometry.containsPoint(try Coordinate(latitude: 42, longitude: 42)))
        #expect(!geometry.containsPoint(try Coordinate(latitude: 20, longitude: 20)))
        #expect(geometry.boundingBox.minLatitude == 0)
        #expect(geometry.boundingBox.maxLatitude == 45)
    }

    @Test func largestPolygonIsTheMainland() throws {
        let mainland = GeoPolygon(outerRing: try ring([(0, 0), (0, 30), (30, 30), (30, 0)]))
        let island = GeoPolygon(outerRing: try ring([(50, 50), (50, 51), (51, 51), (51, 50)]))
        let geometry = try CountryGeometry(polygons: [island, mainland])
        #expect(geometry.largestPolygon?.boundingBox.maxLatitude == 30)
    }

    @Test func geometryRejectsAnEmptyPolygonList() {
        #expect(throws: CountryGeometry.ValidationError.noPolygons) {
            try CountryGeometry(polygons: [])
        }
    }
}

struct AntimeridianTests {
    private func path(_ longitudes: [Double]) throws -> [Coordinate] {
        try longitudes.map { try Coordinate(latitude: 0, longitude: $0) }
    }

    @Test func pathWithoutAWrapStaysWhole() throws {
        let runs = Antimeridian.split(path: try path([-10, 0, 10, 20]))
        #expect(runs.count == 1)
        #expect(runs[0].count == 4)
    }

    /// Without this split, a country touching the 180th meridian is
    /// drawn as a line straight across the globe.
    @Test func pathCrossingTheMeridianIsSplit() throws {
        let runs = Antimeridian.split(path: try path([170, 179, -179, -170]))
        #expect(runs.count == 2)
        #expect(runs[0].map(\.longitude) == [170, 179])
        #expect(runs[1].map(\.longitude) == [-179, -170])
    }

    @Test func detectsCrossings() throws {
        #expect(Antimeridian.crossesAntimeridian(path: try path([179, -179])))
        #expect(!Antimeridian.crossesAntimeridian(path: try path([-179, -170])))
        #expect(!Antimeridian.crossesAntimeridian(path: try path([0])))
    }

    @Test func dropsRunsTooShortToDraw() throws {
        // A single point either side of the wrap leaves nothing to draw.
        let runs = Antimeridian.split(path: try path([179, -179]))
        #expect(runs.isEmpty)
    }
}
