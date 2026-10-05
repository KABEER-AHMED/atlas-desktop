import AppKit
import SceneKit
import AtlasDesktopCore

/// Builds the billboarded plane that carries a country's name.
///
/// Text is rasterized once per country into an image and reused: an
/// `SCNText` per country would add geometry and tessellation cost for no
/// visual gain at label sizes, and an image lets the halo be drawn
/// properly so names stay readable over both land and ocean.
public enum GlobeLabelFactory {
    /// Label height in globe radii. At the default camera distance the
    /// globe's radius covers roughly 275 view points, so this is about
    /// 12 points of cap height — system-typography scale, not a
    /// decorative size.
    public static let heightInRadii = 0.052
    private static let fontSize: CGFloat = 26
    private static let imageScale: CGFloat = 2

    public static func labelNode(for country: Country, theme: GlobeTheme = .standard) -> SCNNode? {
        guard let image = textImage(country.facts.name, theme: theme) else { return nil }

        let aspect = image.size.width / max(image.size.height, 1)
        let height = heightInRadii
        let plane = SCNPlane(width: height * aspect, height: height)

        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.magnificationFilter = .linear
        // Labels are an overlay, not a lit surface, so they stay legible
        // on the night side of the terminator.
        material.lightingModel = .constant
        material.isDoubleSided = false
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        plane.materials = [material]

        let node = SCNNode(geometry: plane)
        node.name = "label.\(country.id.rawValue)"
        let point = SphereProjection.point(for: country.labelAnchor, radius: GlobeTheme.labelRadius)
        node.position = SCNVector3(Float(point.x), Float(point.y), Float(point.z))
        node.constraints = [SCNBillboardConstraint()]
        node.isHidden = true
        return node
    }

    /// The label's on-screen size in view points, for the overlap pass.
    public static func labelSizeInPoints(for country: Country, pointsPerRadius: CGFloat) -> CGSize {
        guard let image = textImage(country.facts.name) else { return .zero }
        let height = CGFloat(heightInRadii) * pointsPerRadius
        let aspect = image.size.width / max(image.size.height, 1)
        return CGSize(width: height * aspect, height: height)
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: NSImage] = [:]

    static func textImage(_ text: String, theme: GlobeTheme = .standard) -> NSImage? {
        cacheLock.lock()
        if let cached = cache[text] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.labelText,
            // A dark outline around the glyphs, so a name crossing from
            // land to ocean keeps its contrast (FR-11).
            .strokeColor: theme.labelHalo,
            .strokeWidth: -5.0
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        guard textSize.width > 0, textSize.height > 0 else { return nil }

        let padding: CGFloat = 6
        let size = CGSize(width: ceil(textSize.width + padding * 2), height: ceil(textSize.height + padding))
        let pixelSize = CGSize(width: size.width * imageScale, height: size.height * imageScale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        string.draw(at: NSPoint(x: padding, y: padding / 2))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)

        cacheLock.lock()
        cache[text] = image
        cacheLock.unlock()
        return image
    }
}
