import CoreGraphics
import Testing
@testable import AtlasGlobeRendering
import AtlasDesktopCore

struct LabelLayoutEngineTests {
    private let viewport = CGSize(width: 800, height: 600)

    private func candidate(
        _ id: String,
        at point: CGPoint,
        size: CGSize = CGSize(width: 60, height: 16),
        priority: Double = 1000,
        frontFacing: Bool = true
    ) -> LabelCandidate {
        LabelCandidate(
            id: CountryID(rawValue: id)!,
            screenPoint: point,
            size: size,
            priority: priority,
            isFrontFacing: frontFacing
        )
    }

    @Test func keepsLabelsThatDoNotCollide() {
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [
                candidate("AAA", at: CGPoint(x: 100, y: 100)),
                candidate("BBB", at: CGPoint(x: 400, y: 300)),
                candidate("CCC", at: CGPoint(x: 700, y: 500))
            ],
            viewportSize: viewport
        )
        #expect(visible.count == 3)
    }

    @Test func dropsTheLowerPriorityLabelOfAnOverlappingPair() {
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [
                candidate("BIG", at: CGPoint(x: 400, y: 300), priority: 5000),
                candidate("SML", at: CGPoint(x: 405, y: 303), priority: 10)
            ],
            viewportSize: viewport
        )
        #expect(visible == [CountryID(rawValue: "BIG")!])
    }

    /// A label on the far side of the globe would float over the wrong
    /// place entirely.
    @Test func dropsLabelsOnTheFarSide() {
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [candidate("AAA", at: CGPoint(x: 400, y: 300), frontFacing: false)],
            viewportSize: viewport
        )
        #expect(visible.isEmpty)
    }

    @Test func dropsLabelsThatWouldBeClippedByTheViewportEdge() {
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [
                candidate("LFT", at: CGPoint(x: 5, y: 300)),
                candidate("TOP", at: CGPoint(x: 400, y: 2)),
                candidate("RGT", at: CGPoint(x: 798, y: 300))
            ],
            viewportSize: viewport
        )
        #expect(visible.isEmpty)
    }

    @Test func appliesTheSizeThreshold() {
        let candidates = [
            candidate("BIG", at: CGPoint(x: 200, y: 200), priority: 900),
            candidate("SML", at: CGPoint(x: 600, y: 400), priority: 5)
        ]
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: candidates,
            viewportSize: viewport,
            minimumPriority: 100
        )
        #expect(visible == [CountryID(rawValue: "BIG")!])
    }

    /// Selecting a small country should name it on the globe, so the
    /// size threshold is waived for the selection — but occlusion is
    /// not.
    @Test func theSelectedCountryIsExemptFromTheSizeThreshold() {
        let selected = CountryID(rawValue: "SML")!
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [candidate("SML", at: CGPoint(x: 400, y: 300), priority: 1)],
            viewportSize: viewport,
            minimumPriority: 500,
            alwaysInclude: selected
        )
        #expect(visible == [selected])
    }

    @Test func theSelectedCountryIsStillHiddenOnTheFarSide() {
        let selected = CountryID(rawValue: "SML")!
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [candidate("SML", at: CGPoint(x: 400, y: 300), priority: 1, frontFacing: false)],
            viewportSize: viewport,
            minimumPriority: 0,
            alwaysInclude: selected
        )
        #expect(visible.isEmpty)
    }

    @Test func theSelectedCountryWinsAgainstAnOverlappingLargerNeighbour() {
        let selected = CountryID(rawValue: "SML")!
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [
                candidate("BIG", at: CGPoint(x: 400, y: 300), priority: 9000),
                candidate("SML", at: CGPoint(x: 404, y: 302), priority: 1)
            ],
            viewportSize: viewport,
            alwaysInclude: selected
        )
        #expect(visible.first == selected)
    }

    @Test func respectsTheLabelBudget() {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let candidates: [LabelCandidate] = (0..<24).map { index in
            let id = "A\(letters[index / 5])\(letters[index % 5])"
            let x: CGFloat = 60 + CGFloat(index % 6) * 120
            let y: CGFloat = 60 + CGFloat(index / 6) * 100
            return candidate(id, at: CGPoint(x: x, y: y), priority: Double(1000 - index))
        }
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: candidates,
            viewportSize: viewport,
            maxLabels: 5
        )
        #expect(visible.count == 5)
    }

    /// The same camera must always produce the same labels, or labels
    /// flicker as ties are broken differently frame to frame.
    @Test func layoutIsDeterministicForEqualPriorities() {
        let candidates = [
            candidate("CCC", at: CGPoint(x: 400, y: 300), priority: 100),
            candidate("AAA", at: CGPoint(x: 402, y: 302), priority: 100),
            candidate("BBB", at: CGPoint(x: 404, y: 304), priority: 100)
        ]
        let first = LabelLayoutEngine.visibleLabels(candidates: candidates, viewportSize: viewport)
        let second = LabelLayoutEngine.visibleLabels(candidates: candidates.reversed(), viewportSize: viewport)
        #expect(first == second)
        #expect(first == [CountryID(rawValue: "AAA")!])
    }

    @Test func returnsNothingForADegenerateViewport() {
        let visible = LabelLayoutEngine.visibleLabels(
            candidates: [candidate("AAA", at: .zero)],
            viewportSize: .zero
        )
        #expect(visible.isEmpty)
    }

    /// Zooming in must let smaller countries be named.
    @Test func theSizeThresholdFallsAsTheCameraMovesIn() {
        let far = LabelLayoutEngine.minimumPriority(forDistance: CameraState.maxDistance)
        let near = LabelLayoutEngine.minimumPriority(forDistance: CameraState.minDistance)
        #expect(near < far)
    }
}
