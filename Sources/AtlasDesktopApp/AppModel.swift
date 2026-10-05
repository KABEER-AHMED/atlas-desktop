import SwiftUI
import AppKit
import AtlasDesktopCore
import AtlasGeographyData
import AtlasGlobeRendering

/// Assembles the app's dependencies and owns the pieces that are not
/// part of the globe's product state: the presentation-mode window and
/// the menu-bar item.
///
/// Dependencies are injected rather than reached for, so a test (or a
/// future preview) can run the whole UI against a fixture dataset and an
/// in-memory preferences store.
@MainActor
@Observable
public final class AppModel {
    public let session: GlobeSession
    public let presentation: PresentationModeController

    private var menuBar: MenuBarController?
    /// Mirrors the system reduce-motion setting; refreshed from the
    /// workspace notification rather than polled.
    private var reduceMotion: Bool

    public init(
        repository: GeographyRepository = BundledGeographyRepository(),
        preferencesStore: PreferencesStore = UserDefaultsPreferencesStore()
    ) {
        let initialReduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        self.reduceMotion = initialReduceMotion

        // The session reads reduce-motion through a closure so it never
        // depends on AppKit; `AppModel` keeps the value current.
        var readReduceMotion: (@MainActor () -> Bool)!
        let session = GlobeSession(
            repository: repository,
            preferencesStore: preferencesStore,
            reducedMotionProvider: { readReduceMotion() }
        )
        self.session = session
        self.presentation = PresentationModeController()
        readReduceMotion = { [weak self] in self?.reduceMotion ?? initialReduceMotion }

        observeReduceMotion()
    }

    /// Launch argument that enters desktop presentation mode straight
    /// away. It exists for manual verification of that mode — the mode
    /// itself cannot be entered from a script, since doing so through
    /// the menus would need Accessibility permission the app must not
    /// ask for. Documented in docs/TESTING.md.
    public static let presentationLaunchArgument = "--enter-presentation"

    public func start() {
        Task { await session.load() }
        menuBar = MenuBarController(model: self)

        if CommandLine.arguments.contains(Self.presentationLaunchArgument) {
            togglePresentationMode()
        }
    }

    private func observeReduceMotion() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
    }

    // MARK: - Commands shared by the menu bar, the main menu and the UI

    public func togglePresentationMode() {
        presentation.toggle(session: session)
    }

    public func exitPresentationMode() {
        presentation.exit()
    }

    public func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // The SwiftUI window may have been closed; `newWindowForTab` is
        // not available for a WindowGroup, so an existing window is
        // raised and otherwise the standard reopen path is used.
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.contentViewController != nil }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.sendAction(Selector(("newDocument:")), to: nil, from: nil)
        }
    }

    public var isPresentationModeActive: Bool { presentation.isActive }
}
