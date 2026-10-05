import AtlasDesktopCore

/// ⚠️ SPIKE-ONLY, NOT REAL DATA. ⚠️
///
/// These are hand-approximated, low-point-count outlines for exactly
/// two recognizable landmasses, used only to put *something* with a
/// plausible non-trivial shape on the sphere so the renderer
/// comparison in docs/adr/0002-renderer-choice.md has a real polygon
/// to push through each pipeline (decode → project → draw → hit-test).
///
/// They are NOT sourced from a licensed dataset, are NOT
/// geographically accurate, and MUST NOT ship in any build beyond
/// this spike. Milestone 2 (docs/IMPLEMENTATION_PLAN.md) replaces
/// this entirely with a real, licensed, attributed dataset and a
/// reproducible conversion pipeline — per the execution rule: "Do not
/// substitute a mock globe, hard-coded sample country... for the real
/// data pipeline."
public enum PlaceholderOutlines {
    /// Very rough Madagascar-shaped silhouette (chosen as an island —
    /// no antimeridian handling needed for this shape).
    public static func roughIslandOutline() -> [Coordinate] {
        let raw: [(Double, Double)] = [
            (-12.0, 49.4), (-13.5, 50.0), (-15.5, 50.2), (-17.0, 49.6),
            (-19.0, 48.0), (-20.5, 47.3), (-22.0, 47.6), (-23.5, 47.1),
            (-25.0, 45.5), (-25.2, 44.0), (-23.8, 43.6), (-22.0, 43.3),
            (-20.0, 44.3), (-18.0, 44.0), (-16.0, 44.8), (-14.5, 46.3),
            (-12.0, 49.4) // closed ring
        ]
        return raw.compactMap { try? Coordinate(latitude: $0.0, longitude: $0.1) }
    }

    /// Very rough closed outline roughly covering Anatolia's bounding
    /// shape — again, a placeholder silhouette, not a traced border.
    public static func roughPeninsulaOutline() -> [Coordinate] {
        let raw: [(Double, Double)] = [
            (36.0, 27.0), (36.8, 30.5), (36.5, 34.0), (37.0, 37.0),
            (38.5, 39.0), (40.0, 41.5), (41.5, 41.0), (42.0, 38.0),
            (41.0, 34.0), (41.5, 29.0), (40.0, 26.5), (38.0, 26.3),
            (36.0, 27.0) // closed ring
        ]
        return raw.compactMap { try? Coordinate(latitude: $0.0, longitude: $0.1) }
    }
}
