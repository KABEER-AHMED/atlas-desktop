import AppKit
import SceneKit
import QuartzCore
import AtlasDesktopCore
import os

/// What the globe view reports back to the app.
@MainActor
public protocol GlobeInteractionDelegate: AnyObject {
    func globeViewDidBeginInteraction()
    func globeViewDidEndInteraction()
    func globeView(didDragBy deltaX: Double, deltaY: Double, degreesPerPoint: Double)
    func globeView(didZoomBy factor: Double)
    func globeView(didClickAt coordinate: Coordinate?)
    /// Called once per display frame while the globe is animating, with
    /// the time since the previous frame.
    func globeViewDidTick(elapsed: TimeInterval)
}

/// The `SCNView` the globe is drawn in: input handling, display-link
/// frame pacing, lifecycle-driven suspension, and accessibility.
///
/// SceneKit's `allowsCameraControl` is deliberately unused — it would
/// move the camera behind the app's back, leaving `CameraState` no
/// longer describing what is on screen, and it has no zoom bounds.
///
/// ## Frame pacing and idle behaviour
///
/// Rendering is driven by a `CADisplayLink`, so frames land on the
/// display's refresh rather than on a timer. The link runs only while
/// something is actually moving: auto-rotation, a drag, or a short burst
/// after a state change so one-off updates (a new selection, a settings
/// change) are drawn. Otherwise it is paused and `rendersContinuously`
/// is off, which is what keeps a paused globe near zero CPU. It is also
/// paused when the window is occluded, miniaturized, hidden, or off
/// screen.
@MainActor
public final class GlobeInteractionView: SCNView {
    private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "globeview")

    /// Degrees of rotation per view point of drag at the default camera
    /// distance. Chosen so a drag across a 900-point window turns the
    /// globe about three quarters of a turn — fast enough to cross the
    /// Pacific in one gesture, slow enough to land on a country.
    public static let degreesPerPoint = 0.32
    /// Movement under this many points is a click, not a drag.
    private static let clickSlop: CGFloat = 3

    public weak var interactionDelegate: GlobeInteractionDelegate?

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    /// Frames still owed to a one-off state change.
    private var transientFrameBudget = 0
    private var wantsContinuousAnimation = false
    private var isDragging = false
    private var dragDistance: CGFloat = 0
    private var mouseDownLocation: CGPoint?
    private var observers: [NSObjectProtocol] = []

    public override var acceptsFirstResponder: Bool { true }
    /// Accept the click that would otherwise only activate the window.
    /// In desktop presentation mode the window is deliberately not
    /// active, and a user dragging the globe there should not have to
    /// click twice.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    public override var isOpaque: Bool { true }

    public override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GlobeInteractionView is created in code only")
    }

    private func configure() {
        allowsCameraControl = false
        autoenablesDefaultLighting = false
        antialiasingMode = .multisampling2X
        isJitteringEnabled = false
        rendersContinuously = false
        isPlaying = false
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Interactive globe")
    }

    // MARK: - Lifecycle

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()

        guard let window else {
            // Leaving the window hierarchy must invalidate the link:
            // `CADisplayLink` retains its target, so an abandoned link
            // would both keep this view alive and keep rendering.
            stopDisplayLink()
            return
        }

        let centre = NotificationCenter.default
        let names: [NSNotification.Name] = [
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification
        ]
        for name in names {
            observers.append(
                centre.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.updateRenderingActivity() }
                }
            )
        }
        observers.append(
            centre.addObserver(
                forName: NSApplication.didHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateRenderingActivity() }
            }
        )
        observers.append(
            centre.addObserver(
                forName: NSApplication.didUnhideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateRenderingActivity() }
            }
        )

        requestTransientRender()
        updateRenderingActivity()
    }

    /// True when drawing this view could actually be seen.
    private var isVisibleOnScreen: Bool {
        guard let window else { return false }
        if NSApp?.isHidden == true { return false }
        if window.isMiniaturized { return false }
        if !window.isVisible { return false }
        if !window.occlusionState.contains(.visible) { return false }
        return true
    }

    /// Whether the globe should be animating continuously. Set by the
    /// app from session state.
    public func setContinuousAnimation(_ enabled: Bool) {
        guard wantsContinuousAnimation != enabled else { return }
        wantsContinuousAnimation = enabled
        updateRenderingActivity()
    }

    /// Asks for a short burst of frames so a one-off change is drawn
    /// even while the globe is otherwise static.
    public func requestTransientRender(frames: Int = 4) {
        transientFrameBudget = max(transientFrameBudget, frames)
        updateRenderingActivity()
    }

    private func updateRenderingActivity() {
        let shouldRun = isVisibleOnScreen && (wantsContinuousAnimation || isDragging || transientFrameBudget > 0)
        if shouldRun {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
    }

    private func startDisplayLink()  {
        rendersContinuously = true
        isPlaying = true
        if displayLink == nil {
            let link = displayLink(target: self, selector: #selector(handleDisplayLink(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastFrameTimestamp = nil
            Self.logger.debug("Display link started")
        }
        displayLink?.isPaused = false
    }

    private func stopDisplayLink() {
        guard displayLink != nil else {
            rendersContinuously = false
            isPlaying = false
            return
        }
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil
        rendersContinuously = false
        isPlaying = false
        Self.logger.debug("Display link stopped")
    }

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        let now = link.timestamp
        let elapsed: TimeInterval
        if let last = lastFrameTimestamp {
            // Clamp the step so a stall (sleep/wake, a slow frame) can
            // never jump the globe by a large rotation.
            elapsed = min(max(now - last, 0), 0.1)
        } else {
            elapsed = 0
        }
        lastFrameTimestamp = now

        if transientFrameBudget > 0 { transientFrameBudget -= 1 }
        interactionDelegate?.globeViewDidTick(elapsed: elapsed)

        if !wantsContinuousAnimation && !isDragging && transientFrameBudget <= 0 {
            stopDisplayLink()
        }
    }

    // MARK: - Pointer input

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        dragDistance = 0
        isDragging = false
    }

    public override func mouseDragged(with event: NSEvent) {
        if !isDragging {
            isDragging = true
            interactionDelegate?.globeViewDidBeginInteraction()
            updateRenderingActivity()
        }
        dragDistance += abs(event.deltaX) + abs(event.deltaY)
        // AppKit's deltaY is positive downward; the camera API takes
        // upward-positive, matching "the globe follows the pointer".
        interactionDelegate?.globeView(
            didDragBy: Double(event.deltaX),
            deltaY: Double(-event.deltaY),
            degreesPerPoint: Self.degreesPerPoint
        )
    }

    public override func mouseUp(with event: NSEvent) {
        let wasDragging = isDragging
        isDragging = false

        if wasDragging {
            interactionDelegate?.globeViewDidEndInteraction()
        }

        if !wasDragging || dragDistance < Self.clickSlop {
            let point = convert(event.locationInWindow, from: nil)
            // A click on the globe selects; a click on empty space
            // clears the selection (the documented FR-03 behaviour).
            interactionDelegate?.globeView(didClickAt: coordinate(at: point))
        }
        requestTransientRender()
    }

    public override func scrollWheel(with event: NSEvent) {
        // Precise deltas come from a trackpad or a Magic Mouse and
        // arrive in small increments; a notched wheel sends ±1 per
        // click. Normalizing here keeps the zoom rate comparable.
        let step = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.scrollingDeltaY * 0.1
        guard step != 0 else { return }
        interactionDelegate?.globeView(didZoomBy: exp(-Double(step)))
        requestTransientRender()
    }

    public override func magnify(with event: NSEvent) {
        guard event.magnification != 0 else { return }
        interactionDelegate?.globeView(didZoomBy: 1 / (1 + Double(event.magnification)))
        requestTransientRender()
    }

    /// Exposed so the app can map a point (from a click or a test) to a
    /// coordinate using the renderer's own transforms.
    public var coordinateResolver: ((CGPoint, CGSize) -> Coordinate?)?

    private func coordinate(at point: CGPoint) -> Coordinate? {
        coordinateResolver?(point, bounds.size)
    }

    // MARK: - Keyboard

    /// Keyboard equivalents for every pointer gesture, so the globe can
    /// be driven without a mouse or trackpad (FR-11). Menu commands
    /// cover the mode toggles; these cover navigation.
    public override func keyDown(with event: NSEvent) {
        let step = event.modifierFlags.contains(.shift) ? 15.0 : 5.0
        let points = step / Self.degreesPerPoint

        switch event.specialKey {
        case .leftArrow:
            interactionDelegate?.globeView(didDragBy: points, deltaY: 0, degreesPerPoint: Self.degreesPerPoint)
        case .rightArrow:
            interactionDelegate?.globeView(didDragBy: -points, deltaY: 0, degreesPerPoint: Self.degreesPerPoint)
        case .upArrow:
            interactionDelegate?.globeView(didDragBy: 0, deltaY: -points, degreesPerPoint: Self.degreesPerPoint)
        case .downArrow:
            interactionDelegate?.globeView(didDragBy: 0, deltaY: points, degreesPerPoint: Self.degreesPerPoint)
        default:
            switch event.charactersIgnoringModifiers {
            case "+", "=":
                interactionDelegate?.globeView(didZoomBy: 1 / 1.2)
            case "-", "_":
                interactionDelegate?.globeView(didZoomBy: 1.2)
            default:
                super.keyDown(with: event)
                return
            }
        }
        requestTransientRender()
    }

    // MARK: - Resize

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // The label layout depends on viewport size, so a resize needs a
        // relayout — but the camera state must survive it untouched.
        requestTransientRender()
    }
}
