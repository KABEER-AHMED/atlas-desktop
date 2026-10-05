import Foundation
import Testing
@testable import AtlasDesktopCore

struct CameraStateTests {
    @Test func homeViewLooksAtTheOriginOfTheGraticule() throws {
        let centre = try #require(CameraState.home.centerCoordinate)
        #expect(abs(centre.latitude) < 1e-9)
        #expect(abs(centre.longitude) < 1e-9)
    }

    /// The whole convention in one check: the two stored angles are the
    /// latitude and longitude at the centre of the view, derived through
    /// the real transforms rather than asserted.
    @Test(arguments: [(0.0, 0.0), (45.0, 20.0), (-100.0, 30.0), (170.0, -60.0), (-179.0, 0.0)])
    func yawAndPitchAreTheCentreCoordinate(yaw: Double, pitch: Double) throws {
        let camera = CameraState(yawDegrees: yaw, pitchDegrees: pitch, distance: 2.4)
        let centre = try #require(camera.centerCoordinate)
        #expect(abs(centre.latitude - pitch) < 1e-6)
        #expect(abs(Coordinate.normalizedLongitude(centre.longitude - yaw)) < 1e-6)
    }

    @Test func modelAndWorldTransformsAreInverses() throws {
        let camera = CameraState(yawDegrees: 73, pitchDegrees: -28, distance: 2)
        let model = SphereProjection.point(for: try Coordinate(latitude: 12, longitude: -46))
        let roundTripped = camera.modelPoint(forWorld: camera.worldPoint(forModel: model))

        #expect(abs(roundTripped.x - model.x) < 1e-12)
        #expect(abs(roundTripped.y - model.y) < 1e-12)
        #expect(abs(roundTripped.z - model.z) < 1e-12)
    }

    @Test func pitchIsClampedShortOfThePoles() {
        #expect(CameraState(pitchDegrees: 120).pitchDegrees == CameraState.maxPitch)
        #expect(CameraState(pitchDegrees: -120).pitchDegrees == -CameraState.maxPitch)
    }

    @Test func yawWrapsInsteadOfGrowingWithoutBound() {
        #expect(CameraState(yawDegrees: 540).yawDegrees == 180)
        #expect(CameraState(yawDegrees: -190).yawDegrees == 170)
    }

    @Test func distanceIsClampedToTheZoomBounds() {
        #expect(CameraState(distance: 0.1).distance == CameraState.minDistance)
        #expect(CameraState(distance: 99).distance == CameraState.maxDistance)
        #expect(CameraState(distance: .nan).distance == CameraState.defaultDistance)
    }

    /// Dragging must move the globe *with* the pointer. Dragging right
    /// brings more westerly longitudes to the centre; dragging up brings
    /// more southerly latitudes. Reversing either of these is the
    /// "inverted controls" bug.
    @Test func draggingMovesTheGlobeWithThePointer() {
        var camera = CameraState.home
        camera.applyDrag(deltaX: 100, deltaY: 0, degreesPerPoint: 0.3)
        #expect(camera.yawDegrees < 0)

        camera = .home
        camera.applyDrag(deltaX: -100, deltaY: 0, degreesPerPoint: 0.3)
        #expect(camera.yawDegrees > 0)

        camera = .home
        camera.applyDrag(deltaX: 0, deltaY: 100, degreesPerPoint: 0.3)
        #expect(camera.pitchDegrees < 0)

        camera = .home
        camera.applyDrag(deltaX: 0, deltaY: -100, degreesPerPoint: 0.3)
        #expect(camera.pitchDegrees > 0)
    }

    @Test func draggingSlowsDownAsTheCameraMovesCloser() {
        var far = CameraState(distance: CameraState.maxDistance)
        var near = CameraState(distance: CameraState.minDistance)
        far.applyDrag(deltaX: -50, deltaY: 0, degreesPerPoint: 0.3)
        near.applyDrag(deltaX: -50, deltaY: 0, degreesPerPoint: 0.3)
        #expect(near.yawDegrees < far.yawDegrees)
    }

    @Test func dragIgnoresNonFiniteInput() {
        var camera = CameraState.home
        camera.applyDrag(deltaX: .nan, deltaY: 0, degreesPerPoint: 0.3)
        #expect(camera == .home)
    }

    @Test func zoomStaysWithinBoundsAndReportsThem() {
        var camera = CameraState.home
        for _ in 0..<80 { camera.applyZoom(factor: 0.9) }
        #expect(camera.distance == CameraState.minDistance)
        #expect(camera.isAtMinimumDistance)

        for _ in 0..<80 { camera.applyZoom(factor: 1.1) }
        #expect(camera.distance == CameraState.maxDistance)
        #expect(camera.isAtMaximumDistance)
    }

    @Test func zoomIgnoresNonsenseFactors() {
        var camera = CameraState.home
        camera.applyZoom(factor: 0)
        camera.applyZoom(factor: -2)
        camera.applyZoom(factor: .nan)
        #expect(camera.distance == CameraState.defaultDistance)
    }

    @Test func autoRotationAdvancesByElapsedTime() {
        var camera = CameraState.home
        camera.advanceAutoRotation(degreesPerSecond: 6, elapsed: 0.5)
        #expect(abs(camera.yawDegrees - 3) < 1e-9)
    }

    @Test func autoRotationIgnoresNonPositiveSteps() {
        var camera = CameraState.home
        camera.advanceAutoRotation(degreesPerSecond: 6, elapsed: 0)
        camera.advanceAutoRotation(degreesPerSecond: 6, elapsed: -1)
        #expect(camera.yawDegrees == 0)
    }

    @Test func cameraStateSurvivesACodableRoundTrip() throws {
        let camera = CameraState(yawDegrees: 37.5, pitchDegrees: -12.25, distance: 2.125)
        let decoded = try JSONDecoder().decode(
            CameraState.self,
            from: try JSONEncoder().encode(camera)
        )
        #expect(decoded == camera)
    }
}