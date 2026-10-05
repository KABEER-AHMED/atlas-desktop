import AppKit
import CoreGraphics
import AtlasDesktopCore

/// Builds the globe's equirectangular textures from a `CountryIndexMap`.
///
/// Two textures, both generated from the same index map:
/// - the **base** texture, ocean and land, built once at load;
/// - the **selection overlay**, transparent except for the selected
///   country, rebuilt on each selection change.
///
/// The overlay is a full-size texture rather than a cropped one because
/// a sub-rect would need its own UV mapping on the sphere; a full pass
/// over 2M pixels is a few milliseconds and runs off the main actor.
public enum GlobeTextureFactory {
    /// Opaque ocean/land texture.
    public static func baseTexture(from map: CountryIndexMap, theme: GlobeTheme = .standard) -> CGImage? {
        let ocean = components(of: theme.ocean)
        let land = components(of: theme.land)

        var pixels = [UInt8](repeating: 0, count: map.width * map.height * 4)
        for pixelIndex in 0..<(map.width * map.height) {
            let colour = map.indices[pixelIndex] == 0 ? ocean : land
            let offset = pixelIndex * 4
            pixels[offset] = colour.0
            pixels[offset + 1] = colour.1
            pixels[offset + 2] = colour.2
            pixels[offset + 3] = 255
        }
        return image(from: pixels, width: map.width, height: map.height)
    }

    /// Overlay texture tinting exactly one country, or `nil` when
    /// nothing is selected (the caller then hides the overlay layer
    /// rather than uploading a fully transparent texture).
    public static func selectionOverlay(
        from map: CountryIndexMap,
        selected: CountryID?,
        theme: GlobeTheme = .standard
    ) -> CGImage? {
        guard let selected,
              let position = map.countryIDs.firstIndex(of: selected) else { return nil }
        let value = UInt16(position + 1)
        let tint = components(of: theme.selectionFill)
        // Enough tint to be unmistakable, light enough that the land
        // shading and the borders drawn above it still read through.
        let alpha: UInt8 = 150

        var pixels = [UInt8](repeating: 0, count: map.width * map.height * 4)
        var matched = false
        for pixelIndex in 0..<(map.width * map.height) where map.indices[pixelIndex] == value {
            let offset = pixelIndex * 4
            // Premultiplied alpha, matching the bitmap info below.
            pixels[offset] = UInt8(Int(tint.0) * Int(alpha) / 255)
            pixels[offset + 1] = UInt8(Int(tint.1) * Int(alpha) / 255)
            pixels[offset + 2] = UInt8(Int(tint.2) * Int(alpha) / 255)
            pixels[offset + 3] = alpha
            matched = true
        }
        guard matched else { return nil }

        return image(from: pixels, width: map.width, height: map.height)
    }

    /// Radial gradient for the atmospheric rim.
    ///
    /// A narrow band peaking just outside the globe's silhouette and
    /// fading quickly in both directions. An earlier version spread the
    /// glow across the whole quad, which read as a large pale donut
    /// around the globe rather than as atmosphere; the band is
    /// deliberately tight and dim.
    ///
    /// `limbRadius` is where the globe's edge falls in the texture, as a
    /// fraction of the half-width — it depends on how large the quad is
    /// relative to the globe, so the caller passes it rather than this
    /// function assuming it.
    public static func atmosphereGradient(
        size: Int = 512,
        limbRadius: Double = 0.87,
        theme: GlobeTheme = .standard
    ) -> CGImage? {
        let colour = components(of: theme.atmosphere)
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let centre = Double(size - 1) / 2

        // Widths of the band on each side of the limb. The inner side is
        // tighter: glow bleeding inward washes out the coastlines.
        let innerWidth = 0.035
        let outerWidth = 0.075
        let peakAlpha = 95.0

        for y in 0..<size {
            for x in 0..<size {
                let dx = (Double(x) - centre) / centre
                let dy = (Double(y) - centre) / centre
                let radius = (dx * dx + dy * dy).squareRoot()

                let offset = radius - limbRadius
                let width = offset < 0 ? innerWidth : outerWidth
                let falloff = exp(-(offset * offset) / (2 * width * width))
                // Hard cut at the quad's edge so no band of colour can
                // appear along the texture boundary.
                let edgeFade = radius > 0.99 ? 0.0 : 1.0

                let alpha = UInt8(max(0, min(255, falloff * peakAlpha * edgeFade)))
                let index = (y * size + x) * 4
                pixels[index] = UInt8(Int(colour.0) * Int(alpha) / 255)
                pixels[index + 1] = UInt8(Int(colour.1) * Int(alpha) / 255)
                pixels[index + 2] = UInt8(Int(colour.2) * Int(alpha) / 255)
                pixels[index + 3] = alpha
            }
        }
        return image(from: pixels, width: size, height: size)
    }

    /// A star field for the scene background.
    ///
    /// Generated rather than bundled: a star catalogue would be another
    /// dataset to license and attribute, and nothing here claims to show
    /// real constellations. The generator is seeded, so the same sky is
    /// produced on every launch and every machine — a different sky each
    /// time would be visible as flicker when the scene is rebuilt.
    public static func starField(
        width: Int = 2048,
        height: Int = 1024,
        starCount: Int = 2600,
        theme: GlobeTheme = .standard
    ) -> CGImage? {
        let space = components(of: theme.space)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) {
            let offset = index * 4
            pixels[offset] = space.0
            pixels[offset + 1] = space.1
            pixels[offset + 2] = space.2
            pixels[offset + 3] = 255
        }

        var random = SeededGenerator(seed: 0x61746C61_73303031)

        for _ in 0..<starCount {
            let x = Int(random.nextUnit() * Double(width - 1))
            // Latitude distributed by arcsine, so stars are spread
            // evenly over the sphere rather than crowded at the poles
            // where an equirectangular image compresses.
            let v = random.nextUnit() * 2 - 1
            let y = Int((asin(v) / .pi + 0.5) * Double(height - 1))

            // Most stars faint, a few bright: a steep power curve, which
            // reads far more like a night sky than a uniform spread.
            let brightness = pow(random.nextUnit(), 3.2)
            let peak = 40 + brightness * 215
            // A hint of colour temperature across the field.
            let warmth = random.nextUnit()
            let red = peak * (0.82 + 0.18 * warmth)
            let blue = peak * (0.86 + 0.14 * (1 - warmth))

            plot(&pixels, width: width, height: height, x: x, y: y,
                 red: red, green: peak * 0.94, blue: blue)

            // The brightest stars get a one-pixel halo so they do not
            // disappear when the texture is minified.
            if brightness > 0.72 {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    plot(&pixels, width: width, height: height, x: x + dx, y: y + dy,
                         red: red * 0.3, green: peak * 0.28, blue: blue * 0.3)
                }
            }
        }

        return image(from: pixels, width: width, height: height)
    }

    private static func plot(
        _ pixels: inout [UInt8],
        width: Int, height: Int,
        x: Int, y: Int,
        red: Double, green: Double, blue: Double
    ) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let offset = (y * width + x) * 4
        pixels[offset] = UInt8(max(0, min(255, Double(pixels[offset]) + red)))
        pixels[offset + 1] = UInt8(max(0, min(255, Double(pixels[offset + 1]) + green)))
        pixels[offset + 2] = UInt8(max(0, min(255, Double(pixels[offset + 2]) + blue)))
    }

    private static func components(of color: NSColor) -> (UInt8, UInt8, UInt8) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        return (
            UInt8(max(0, min(255, converted.redComponent * 255))),
            UInt8(max(0, min(255, converted.greenComponent * 255))),
            UInt8(max(0, min(255, converted.blueComponent * 255)))
        )
    }

    private static func image(from pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}


/// A small deterministic generator, so the star field is identical on
/// every launch without depending on the platform's random number
/// generator staying stable across releases.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// xorshift64*, which is plenty for scattering dots.
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
