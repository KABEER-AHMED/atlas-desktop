import AppKit

/// The globe's palette and a few layout constants.
///
/// Dark-first and deliberately restrained (PRD §6): near-black space,
/// a desaturated ocean, land light enough for crisp borders to read
/// against it, and a single amber accent reserved for selection.
/// Collected here so nothing hard-codes a colour mid-render.
public struct GlobeTheme: Sendable {
    public let space: NSColor
    public let ocean: NSColor
    public let land: NSColor
    public let border: NSColor
    public let coastline: NSColor
    public let selectionFill: NSColor
    public let selectionBorder: NSColor
    public let atmosphere: NSColor
    public let labelText: NSColor
    public let labelHalo: NSColor

    public static let standard = GlobeTheme(
        space: NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.067, alpha: 1.0),
        ocean: NSColor(calibratedRed: 0.063, green: 0.106, blue: 0.180, alpha: 1.0),
        land: NSColor(calibratedRed: 0.235, green: 0.290, blue: 0.360, alpha: 1.0),
        // Drawn over photographic imagery, so the border lines are
        // translucent: opaque lines turn the globe into a wire diagram
        // and bury the terrain underneath.
        border: NSColor(calibratedRed: 0.886, green: 0.933, blue: 1.0, alpha: 0.42),
        coastline: NSColor(calibratedRed: 0.447, green: 0.533, blue: 0.639, alpha: 1.0),
        selectionFill: NSColor(calibratedRed: 1.0, green: 0.741, blue: 0.333, alpha: 1.0),
        selectionBorder: NSColor(calibratedRed: 1.0, green: 0.859, blue: 0.600, alpha: 1.0),
        atmosphere: NSColor(calibratedRed: 0.357, green: 0.561, blue: 0.839, alpha: 1.0),
        labelText: NSColor(calibratedWhite: 0.97, alpha: 1.0),
        labelHalo: NSColor(calibratedRed: 0.027, green: 0.035, blue: 0.067, alpha: 0.85)
    )

    /// Radii, in globe radii, for the stacked layers. Each is far enough
    /// above the one below to avoid z-fighting at the zoom limits while
    /// staying visually coincident.
    public static let surfaceRadius = 1.0
    public static let selectionRadius = 1.0015
    public static let borderRadius = 1.003
    public static let atmosphereRadius = 1.09
    public static let labelRadius = 1.02
    public static let markerRadius = 1.006
}
