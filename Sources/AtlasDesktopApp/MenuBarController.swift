import AppKit
import AtlasDesktopCore

/// The menu-bar item.
///
/// It is the mode's escape hatch as much as a convenience: presentation
/// mode ignores mouse events, so this menu (and the View menu) is how a
/// user gets out of it. Every item performs a real action — FR-01 wants
/// menu-bar access to each of these, and AGENTS.md forbids inert menus.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "globe.europe.africa",
                accessibilityDescription: "Atlas Desktop"
            )
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Items are rebuilt each time the menu opens so their titles and
    /// check marks always reflect current state rather than the state
    /// when the app launched.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let session = model.session

        menu.addItem(withTitle: "Show Atlas Desktop", action: #selector(showWindow), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        let rotation = menu.addItem(
            withTitle: session.preferences.autoRotationEnabled ? "Pause Rotation" : "Resume Rotation",
            action: #selector(toggleRotation),
            keyEquivalent: ""
        )
        rotation.target = self
        if session.isAutoRotationSuppressedByReducedMotion {
            rotation.toolTip = "Rotation is switched on but held back by the system’s Reduce Motion setting."
        }

        let learning = menu.addItem(
            withTitle: "Learning Mode",
            action: #selector(toggleLearningMode),
            keyEquivalent: ""
        )
        learning.target = self
        learning.state = session.isLearningModeEnabled ? .on : .off

        let reset = menu.addItem(withTitle: "Reset View", action: #selector(resetView), keyEquivalent: "")
        reset.target = self

        menu.addItem(.separator())

        let presentation = menu.addItem(
            withTitle: model.isPresentationModeActive
                ? "Exit Desktop Presentation"
                : "Enter Desktop Presentation",
            action: #selector(togglePresentation),
            keyEquivalent: ""
        )
        presentation.target = self

        menu.addItem(.separator())

        let settings = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self

        let quit = menu.addItem(withTitle: "Quit Atlas Desktop", action: #selector(quit), keyEquivalent: "")
        quit.target = self
    }

    @objc private func showWindow() { model.showMainWindow() }
    @objc private func toggleRotation() { model.session.toggleAutoRotation() }
    @objc private func toggleLearningMode() { model.session.toggleLearningMode() }
    @objc private func resetView() { model.session.resetView() }
    @objc private func togglePresentation() { model.togglePresentationMode() }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // The selector that opens a SwiftUI `Settings` scene changed
        // name in macOS 13; try the current one first and fall back.
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) { return }
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
