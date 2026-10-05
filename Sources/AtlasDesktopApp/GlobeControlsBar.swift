import SwiftUI
import AtlasDesktopCore

/// The floating control strip over the globe.
///
/// Four controls, each reflecting its own state (PRD §6: "Every
/// state-changing control must visibly reflect its state"), each with an
/// accessible label, a tooltip naming its keyboard shortcut, and a real
/// action behind it.
struct GlobeControlsBar: View {
    let model: AppModel

    private var session: GlobeSession { model.session }

    var body: some View {
        HStack(spacing: 10) {
            ControlButton(
                systemImage: session.preferences.autoRotationEnabled ? "pause.fill" : "play.fill",
                label: session.preferences.autoRotationEnabled ? "Pause rotation" : "Resume rotation",
                tooltip: rotationTooltip,
                isActive: session.isAutoRotating,
                action: { session.toggleAutoRotation() }
            )
            .keyboardShortcut(.space, modifiers: [])

            ControlButton(
                systemImage: "graduationcap.fill",
                label: session.isLearningModeEnabled ? "Turn learning mode off" : "Turn learning mode on",
                tooltip: "Learning mode hides country labels (⌘L)",
                isActive: session.isLearningModeEnabled,
                action: { session.toggleLearningMode() }
            )
            .keyboardShortcut("l", modifiers: .command)

            ControlButton(
                systemImage: "arrow.counterclockwise",
                label: "Reset view",
                tooltip: "Return to the default view (⌘0)",
                isActive: false,
                action: { session.resetView() }
            )
            .keyboardShortcut("0", modifiers: .command)

            ControlButton(
                systemImage: "menubar.dock.rectangle",
                label: model.isPresentationModeActive
                    ? "Exit desktop presentation"
                    : "Enter desktop presentation",
                tooltip: "Desktop presentation mode (⌃⌥⌘D)",
                isActive: model.isPresentationModeActive,
                action: { model.togglePresentationMode() }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }

    private var rotationTooltip: String {
        if session.isAutoRotationSuppressedByReducedMotion {
            return "Rotation is on, but the system’s Reduce Motion setting is holding it back (Space)"
        }
        return session.preferences.autoRotationEnabled
            ? "Pause the slow rotation (Space)"
            : "Resume the slow rotation (Space)"
    }
}

private struct ControlButton: View {
    let systemImage: String
    let label: String
    let tooltip: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 20)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        // State is carried by the label and the accessibility trait as
        // well as by colour, so it is never colour alone (FR-11).
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .help(tooltip)
    }
}
