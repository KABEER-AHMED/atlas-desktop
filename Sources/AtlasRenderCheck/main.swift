import AppKit
import SceneKit
import Metal
import AtlasDesktopCore
import AtlasGeographyData
import AtlasGlobeRendering

// Renders the real globe scene offscreen and writes PNGs.
//
//     swift run AtlasRenderCheck [output-directory]
//
// A rendering smoke check that needs no window, no display and no
// screen-recording permission: it builds the same scene the app shows,
// through the same loading, rasterization and geometry code, and renders
// it with `SCNRenderer`. It exits non-zero if the data does not load, if
// the raster disagrees with the selection lookup, or if a render comes
// out blank.
//
// It is not a pixel-comparison test. It answers "does the globe actually
// draw, and does it draw land where land belongs" — the part the unit
// tests cannot reach.

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/render-check"
)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// SceneKit's image and text paths want an initialized app object even
// when nothing is shown on screen.
_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

guard let device = MTLCreateSystemDefaultDevice() else {
    fail("no Metal device available; this check needs a GPU")
}

let loadStart = Date()
let semaphore = DispatchSemaphore(value: 0)
nonisolated(unsafe) var loaded: GeographyDataset?
nonisolated(unsafe) var loadFailure: String?

// `Task.detached`, not `Task`: top-level code is main-actor isolated, so
// a plain `Task` would inherit that actor and never run while the main
// thread is parked on the semaphore below.
Task.detached {
    do {
        loaded = try await BundledGeographyRepository().load()
    } catch {
        loadFailure = error.localizedDescription
    }
    semaphore.signal()
}
semaphore.wait()

if let loadFailure { fail("geography did not load: \(loadFailure)") }
guard let dataset = loaded else { fail("geography did not load") }
print(String(
    format: "Loaded %d countries in %.0f ms",
    dataset.countries.count,
    Date().timeIntervalSince(loadStart) * 1000
))

// Timings for the two steps between launch and a drawable globe. They
// are printed rather than asserted: a threshold here would fail on a
// loaded CI machine for reasons that have nothing to do with the code.
// The numbers recorded in docs/TESTING.md come from this output.
let preparationStart = Date()
let resources = GlobeResources.prepare(dataset: dataset)
print(String(
    format: "  rasterize + land texture: %.0f ms",
    Date().timeIntervalSince(preparationStart) * 1000
))

let imageryStart = Date()
_ = EarthImagery.load()
print(String(
    format: "  surface imagery decode: %.0f ms",
    Date().timeIntervalSince(imageryStart) * 1000
))
guard resources.baseTexture != nil else { fail("land texture could not be built") }
if EarthImagery.load() == nil {
    fail("surface imagery is missing from the renderer's resource bundle")
}

// What is drawn and what is clicked must agree: the raster builds the
// highlight, the lookup answers the click.
let probes: [(String, Double, Double, String)] = [
    ("Paris", 48.86, 2.35, "FRA"),
    ("Tokyo", 35.68, 139.69, "JPN"),
    ("Nairobi", -1.29, 36.82, "KEN"),
    ("Brasília", -15.79, -47.88, "BRA"),
    ("mid-Pacific", 0, -150, "ocean")
]
for (name, latitude, longitude, expected) in probes {
    guard let coordinate = try? Coordinate(latitude: latitude, longitude: longitude) else { continue }
    let exact = dataset.lookup.country(at: coordinate)?.id.rawValue ?? "ocean"
    let raster = resources.indexMap.countryID(at: coordinate)?.rawValue ?? "ocean"
    print("  \(name): lookup=\(exact) raster=\(raster) expected=\(expected)")
    if exact != expected { fail("\(name) resolves to \(exact), expected \(expected)") }
    if exact != raster { fail("raster and lookup disagree at \(name)") }
}

@MainActor
func render(camera: CameraState, selection: Country?, labels: Bool, dayNight: Bool, size: CGSize) -> NSImage {
    let controller = GlobeSceneController()
    controller.install(resources: resources)
    controller.setLabelsEnabled(labels)
    controller.apply(camera: camera)
    // A fixed date, so the terminator lands in the same place every run.
    controller.apply(dayNightEnabled: dayNight, date: Date(timeIntervalSince1970: 1_780_000_000))

    if let selection {
        let overlay = GlobeTextureFactory.selectionOverlay(
            from: resources.indexMap,
            selected: selection.id
        )
        controller.apply(selection: selection, overlay: overlay)
    }
    controller.updateLabels(camera: camera, viewportSize: size, force: true)

    let renderer = SCNRenderer(device: device, options: nil)
    renderer.scene = controller.scene
    renderer.pointOfView = controller.cameraNode
    return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
}

/// Fraction of pixels brighter than the background. A blank or black
/// render is the failure this check exists to catch.
func coverage(of image: NSImage) -> Double {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return 0 }
    var lit = 0
    var total = 0
    for y in stride(from: 0, to: rep.pixelsHigh, by: 4) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 4) {
            total += 1
            guard let colour = rep.colorAt(x: x, y: y) else { continue }
            if colour.brightnessComponent > 0.14 { lit += 1 }
        }
    }
    return total == 0 ? 0 : Double(lit) / Double(total)
}

let size = CGSize(width: 900, height: 700)
guard let franceID = CountryID(rawValue: "FRA"), let japanID = CountryID(rawValue: "JPN") else {
    fail("country identifiers could not be built")
}
let france = dataset.lookup.country(id: franceID)
let japan = dataset.lookup.country(id: japanID)

let scenes: [(String, CameraState, Country?, Bool, Bool)] = [
    ("01-home", .home, nil, true, true),
    ("02-europe-selected", CameraState(yawDegrees: 8, pitchDegrees: 44, distance: 2.1), france, true, true),
    ("03-asia-zoomed", CameraState(yawDegrees: 138, pitchDegrees: 36, distance: 1.7), japan, true, true),
    ("04-learning-mode", CameraState(yawDegrees: 20, pitchDegrees: 10, distance: 2.6), nil, false, true),
    ("05-no-day-night", CameraState(yawDegrees: -60, pitchDegrees: 0, distance: 3.0), nil, true, false)
]

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

var failures: [String] = []
for (name, camera, selection, labels, dayNight) in scenes {
    let image = MainActor.assumeIsolated {
        render(camera: camera, selection: selection, labels: labels, dayNight: dayNight, size: size)
    }
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        failures.append("\(name): could not encode the render")
        continue
    }
    let url = outputDirectory.appendingPathComponent("\(name).png")
    do {
        try png.write(to: url)
    } catch {
        failures.append("\(name): \(error.localizedDescription)")
        continue
    }

    let litFraction = coverage(of: image)
    print(String(format: "  %@ -> %@ (%.1f%% lit)", name, url.lastPathComponent, litFraction * 100))
    if litFraction < 0.03 {
        failures.append("\(name): render looks blank (\(Int(litFraction * 100))% lit)")
    }
}

if failures.isEmpty {
    print("Render check passed; images in \(outputDirectory.path)")
} else {
    failures.forEach { FileHandle.standardError.write(Data("error: \($0)\n".utf8)) }
    exit(1)
}
