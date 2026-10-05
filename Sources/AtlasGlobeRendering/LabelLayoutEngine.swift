import CoreGraphics
import Foundation
import AtlasDesktopCore

/// One label's candidacy for being drawn this frame.
public struct LabelCandidate: Equatable, Sendable {
    public let id: CountryID
    /// Position in view coordinates, from projecting the label anchor.
    public let screenPoint: CGPoint
    /// Rendered size of the label's text in view points.
    public let size: CGSize
    /// Ranking value — the country's relative size scaled for the
    /// current zoom. Bigger wins ties and survives culling.
    public let priority: Double
    /// False when the anchor is on the far side of the globe.
    public let isFrontFacing: Bool

    public init(id: CountryID, screenPoint: CGPoint, size: CGSize, priority: Double, isFrontFacing: Bool) {
        self.id = id
        self.screenPoint = screenPoint
        self.size = size
        self.priority = priority
        self.isFrontFacing = isFrontFacing
    }
}

/// Decides which labels are drawn.
///
/// Deliberately a deterministic greedy pass rather than an optimiser
/// (docs/ARCHITECTURE.md: "Start with deterministic placement and
/// modest level-of-detail rules rather than recomputing expensive
/// layouts each frame"). Candidates are sorted by priority, and a label
/// is kept when it is front-facing, on screen, large enough at this
/// zoom, and does not overlap a label already kept. Equal priorities
/// break by identifier, so the same camera always yields the same
/// labels.
///
/// Two labels never trade places frame to frame as a result: a label can
/// only appear or disappear when the camera actually moves it or its
/// occluder.
public enum LabelLayoutEngine {
    /// Upper bound on labels drawn at once. Past roughly this many the
    /// globe reads as clutter rather than a map, and it also bounds the
    /// per-pass cost.
    public static let defaultMaxLabels = 40

    public static func visibleLabels(
        candidates: [LabelCandidate],
        viewportSize: CGSize,
        maxLabels: Int = defaultMaxLabels,
        minimumPriority: Double = 0,
        padding: CGFloat = 4,
        alwaysInclude: CountryID? = nil
    ) -> [CountryID] {
        guard viewportSize.width > 0, viewportSize.height > 0, maxLabels > 0 else { return [] }

        // The selected country is considered first, so a larger
        // neighbour can never push its label out.
        let sorted = candidates.sorted { first, second in
            if (first.id == alwaysInclude) != (second.id == alwaysInclude) {
                return first.id == alwaysInclude
            }
            if first.priority != second.priority { return first.priority > second.priority }
            return first.id.rawValue < second.id.rawValue
        }

        var keptRects: [CGRect] = []
        var kept: [CountryID] = []

        for candidate in sorted {
            guard kept.count < maxLabels else { break }
            // Occlusion is never waived: a label for a country on the
            // far side of the globe would float over the wrong place.
            guard candidate.isFrontFacing else { continue }

            // The size threshold *is* waived for the selected country —
            // selecting a small country should name it on the globe.
            let isSelected = candidate.id == alwaysInclude
            guard isSelected || candidate.priority >= minimumPriority else { continue }

            let rect = CGRect(
                x: candidate.screenPoint.x - candidate.size.width / 2 - padding,
                y: candidate.screenPoint.y - candidate.size.height / 2 - padding,
                width: candidate.size.width + padding * 2,
                height: candidate.size.height + padding * 2
            )

            guard rect.minX >= 0, rect.minY >= 0,
                  rect.maxX <= viewportSize.width, rect.maxY <= viewportSize.height else { continue }
            guard !keptRects.contains(where: { $0.intersects(rect) }) else { continue }

            keptRects.append(rect)
            kept.append(candidate.id)
        }

        return kept
    }

    /// Minimum priority for a label at a given camera distance.
    ///
    /// Zoomed out, only large countries are named; as the camera moves
    /// in, the threshold falls and smaller countries appear. The curve
    /// is the square of the distance ratio because apparent area, not
    /// width, is what governs whether a label fits inside a country.
    public static func minimumPriority(forDistance distance: Double) -> Double {
        let ratio = distance / CameraState.defaultDistance
        return 120 * ratio * ratio
    }
}
