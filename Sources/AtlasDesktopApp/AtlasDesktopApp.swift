import SwiftUI
import AppKit
import AtlasDesktopCore
import AtlasGlobeRendering

/// Atlas Desktop.
///
/// SwiftUI owns the scenes; AppKit is used where it has to be — the
/// menu-bar item, the desktop-level presentation window, and the globe
/// view's input and frame pacing.
@main
struct AtlasDesktopApp: App {
    @State private var model = AppModel()
    @State private var isFinderPresented = false

    var body: some Scene {
        Window("Atlas Desktop", id: "main") {
            MainWindowView(model: model)
                .sheet(isPresented: $isFinderPresented) {
                    CountryFinderView(session: model.session, isPresented: $isFinderPresented)
                }
                .task { model.start() }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1040, height: 660)
        .commands { commands }

        Settings {
            SettingsView(model: model)
        }
    }

    /// Menu-bar commands. Every item FR-01 asks for, each with a
    /// shortcut, each reflecting current state in its title.
    @CommandsBuilder
    private var commands: some Commands {
        CommandGroup(after: .newItem) {
            Button("Find Country…") { isFinderPresented = true }
                .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu("Globe") {
            Button(model.session.preferences.autoRotationEnabled ? "Pause Rotation" : "Resume Rotation") {
                model.session.toggleAutoRotation()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Toggle("Learning Mode", isOn: Binding(
                get: { model.session.isLearningModeEnabled },
                set: { model.session.setLearningMode(enabled: $0) }
            ))
            .keyboardShortcut("l", modifiers: .command)

            Toggle("Day and Night Shading", isOn: Binding(
                get: { model.session.isDayNightEnabled },
                set: { model.session.setDayNight(enabled: $0) }
            ))

            Divider()

            Button("Reset View") { model.session.resetView() }
                .keyboardShortcut("0", modifiers: .command)
            Button("Zoom In") { model.session.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(model.session.camera.isAtMinimumDistance)
            Button("Zoom Out") { model.session.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(model.session.camera.isAtMaximumDistance)

            Divider()

            Button("Clear Selection") { model.session.clearSelection() }
                .disabled(model.session.selectedCountry == nil)
            Button(model.session.areFactsVisible ? "Hide Answer" : "Reveal Answer") {
                model.session.areFactsVisible ? model.session.hideAnswer() : model.session.revealAnswer()
            }
            .disabled(!model.session.isLearningModeEnabled || model.session.selectedCountry == nil)
        }

        CommandGroup(before: .windowList) {
            Button(model.isPresentationModeActive
                   ? "Exit Desktop Presentation"
                   : "Enter Desktop Presentation") {
                model.togglePresentationMode()
            }
            // The presentation window ignores mouse events, so this
            // shortcut and the menu-bar item are the way out of the
            // mode. Both are always available.
            .keyboardShortcut("d", modifiers: [.control, .option, .command])

            Button("Show Globe Window") { model.showMainWindow() }
                .keyboardShortcut("0", modifiers: [.command, .shift])

            Divider()
        }
    }
}
