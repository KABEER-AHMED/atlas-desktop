import AppKit
import Foundation
import os

/// The globe's surface imagery, bundled with the renderer.
///
/// NASA's Blue Marble: Next Generation composite (December 2004,
/// topography and bathymetry), downsampled to 4096×2048 by
/// `AtlasDataTool`. It is a rendering asset rather than geographic data:
/// nothing is measured from it and no fact in the UI comes from it —
/// borders, names and capitals all come from Natural Earth.
///
/// It is public domain; NASA asks for credit, which the app gives in
/// Settings › Data & Credits. See docs/DATA_AND_LICENSES.md.
public enum EarthImagery {
    private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "imagery")

    public static let resourceName = "atlas-earth"
    public static let resourceExtension = "jpg"

    public static let attribution =
        "Surface imagery: NASA Earth Observatory, Blue Marble: Next Generation, by Reto Stöckli."

    /// The imagery, or `nil` when the resource is missing.
    ///
    /// A missing texture is not fatal: the globe falls back to flat
    /// ocean and land colours drawn from the country data, so the app
    /// stays usable and the failure is logged rather than hidden.
    /// The renderer's own resource bundle.
    public static var resourceBundle: Bundle { .module }

    public static func load(from bundle: Bundle? = nil) -> NSImage? {
        let bundle = bundle ?? resourceBundle
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            logger.error("Surface imagery resource is missing from the bundle")
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            logger.error("Surface imagery could not be decoded")
            return nil
        }
        return image
    }
}
