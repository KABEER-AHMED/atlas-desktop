import AppKit
import SwiftUI
import AtlasDesktopCore
import AtlasGlobeRendering
import os

/// Desktop presentation mode.
///
/// ## What this does, and what macOS actually allows
///
/// macOS gives no public API that lets a third-party app become the
/// wallpaper — nothing puts an ordinary app's window *beneath* the
/// desktop icons across every Space, display and Stage Manager
/// configuration. Private APIs, injection, Accessibility automation and
/// screen capture are all off the table (PRD §FR-08, §10).
///
/// What is available, and what this uses, is a borderless window one
/// level **below the desktop icon layer**
/// (`CGWindowLevelForKey(.desktopIconWindow) - 1`) that joins all Spaces
/// and is excluded from Mission Control cycling. In practice it sits
/// above the wallpaper and below the icons on the displays and Spaces
/// where the window server honours that level, and it is honestly
/// labelled in the UI as a desktop *companion* mode rather than a
/// wallpaper replacement.
///
/// The globe stays interactive in this mode — drag to rotate, scroll to
/// zoom, click to select — which is what makes it a desktop companion
/// rather than a picture. Three rules keep that from interfering with
/// anything else:
/// - The window sits *below* the desktop icon layer, so the icons are
///   above it and keep receiving their own clicks; only clicks on empty
///   desktop reach the globe.
/// - It never becomes main and is never activated on entry, so showing
///   it does not take focus from whatever the user is working in. It can
///   become key only when the user clicks it directly, which is what
///   makes keyboard and scroll input work.
/// - `acceptsFirstMouse` on the globe view means that first click goes
///   straight to the globe instead of being consumed by activating the
///   app.
///
/// Exit is always available from the menu-bar item and from the app's
/// View menu (⌃⌥⌘D), and leaving presentation mode brings the normal
/// window back.
@MainActor
public final class PresentationModeController {
    private static let logger = Logger(subsystem: "com.atlasdesktop.app", category: "presentation")

    /// A window that refuses focus. Everything else about presentation
    /// mode depends on this: a desktop-level window that could become
    /// key would take the user's keyboard away from the app they are
    /// using.
    private final class NonActivatingWindow: NSWindow {
        /// Can take keyboard focus when the user clicks it — but only
        /// then. Nothing in this controller ever calls `makeKey`.
        override var canBecomeKey: Bool { true }
        /// Never main: the globe must not displace the real main window
        /// in the Window menu or in app activation.
        override var canBecomeMain: Bool { false }
    }

    public private(set) var isActive = false

    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?

    public init() {}

    public func toggle(session: GlobeSession) {
        isActive ? exit() : enter(session: session)
    }

    public func enter(session: GlobeSession) {
        guard !isActive else { return }
        isActive = true
        buildWindows(session: session)

        // Displays can be added, removed or rearranged while the mode is
        // active; the windows are rebuilt rather than left on a screen
        // that no longer exists.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                self.tearDownWindows()
                self.buildWindows(session: session)
            }
        }

        Self.logger.info("Entered desktop presentation mode on \(self.windows.count, privacy: .public) display(s)")
    }

    public func exit() {
        guard isActive else { return }
        isActive = false
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        tearDownWindows()
        Self.logger.info("Exited desktop presentation mode")
    }

    private func buildWindows(session: GlobeSession) {
        // One window per display, so a globe appears on each screen
        // rather than only the main one.
        for screen in NSScreen.screens {
            let window = NonActivatingWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window.isOpaque = true
            window.backgroundColor = GlobeTheme.standard.space
            window.hasShadow = false
            // The globe is interactive here, so mouse events are not
            // passed through. Desktop icons remain clickable because
            // they sit on a higher window level than this one.
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.animationBehavior = .none
            window.setAccessibilityLabel("Atlas Desktop presentation globe")

            let hosting = NSHostingView(
                rootView: PresentationGlobeView(session: session)
                    .frame(width: screen.frame.width, height: screen.frame.height)
            )
            window.contentView = hosting
            window.setFrame(screen.frame, display: true)
            window.orderBack(nil)
            windows.append(window)
        }
    }

    private func tearDownWindows() {
        for window in windows {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}

/// The globe alone, with no chrome, for presentation mode.
struct PresentationGlobeView: View {
    let session: GlobeSession

    var body: some View {
        ZStack {
            Color(GlobeTheme.standard.space)
            if session.loadState == .ready {
                GlobeView(session: session)
            }
        }
        .ignoresSafeArea()
    }
}
