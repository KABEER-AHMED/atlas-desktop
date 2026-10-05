import SwiftUI
import AtlasDesktopCore

/// Native settings. Every change applies immediately and is persisted
/// at once — nothing here needs a restart (FR-09).
struct SettingsView: View {
    let model: AppModel

    private var session: GlobeSession { model.session }

    var body: some View {
        TabView {
            globeTab
                .tabItem { Label("Globe", systemImage: "globe") }
            dataTab
                .tabItem { Label("Data & Credits", systemImage: "info.circle") }
        }
        .frame(width: 460)
        .padding(18)
    }

    private var globeTab: some View {
        Form {
            Section("Motion") {
                Toggle("Rotate the globe automatically", isOn: binding(
                    get: { session.preferences.autoRotationEnabled },
                    set: { session.setAutoRotation(enabled: $0) }
                ))

                VStack(alignment: .leading, spacing: 2) {
                    Slider(
                        value: binding(
                            get: { session.preferences.autoRotationDegreesPerSecond },
                            set: { session.setAutoRotationSpeed($0) }
                        ),
                        in: Preferences.minRotationSpeed...Preferences.maxRotationSpeed
                    ) {
                        Text("Rotation speed")
                    }
                    .disabled(!session.preferences.autoRotationEnabled)
                    .accessibilityValue(rotationSpeedDescription)

                    Text(rotationSpeedDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle("Respect the system’s Reduce Motion setting", isOn: binding(
                    get: { session.preferences.respectsReducedMotion },
                    set: { session.setRespectsReducedMotion($0) }
                ))
                .help("When on, automatic rotation stops while Reduce Motion is enabled in System Settings › Accessibility › Display.")

                if session.isAutoRotationSuppressedByReducedMotion {
                    Label(
                        "Reduce Motion is on, so the globe is not rotating.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                Toggle("Show country labels", isOn: binding(
                    get: { session.preferences.labelsEnabled },
                    set: { session.setLabels(enabled: $0) }
                ))
                .disabled(session.isLearningModeEnabled)
                .help(session.isLearningModeEnabled
                      ? "Learning mode already hides labels."
                      : "Labels appear as you zoom in, largest countries first.")

                Toggle("Show day and night shading", isOn: binding(
                    get: { session.preferences.dayNightEnabled },
                    set: { session.setDayNight(enabled: $0) }
                ))
                .help("Lights the globe from the sun’s approximate current position.")

                Toggle("Learning mode (hide labels)", isOn: binding(
                    get: { session.preferences.learningModeEnabled },
                    set: { session.setLearningMode(enabled: $0) }
                ))
            }

            Section("On launch") {
                Toggle("Restore the last view", isOn: binding(
                    get: { session.preferences.restoresCameraOnLaunch },
                    set: { session.setRestoresCameraOnLaunch($0) }
                ))
                .help("Remembers where the globe was pointing and how far in the camera was.")
            }
        }
        .formStyle(.grouped)
    }

    private var dataTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let provenance = session.dataset?.provenance {
                    Text("Geography data")
                        .font(.headline)
                    LabeledContent("Boundaries", value: provenance.geometrySource)
                    LabeledContent("Version", value: provenance.geometryVersion)
                    LabeledContent("Licence", value: provenance.geometryLicense)
                    LabeledContent("Names & capitals", value: provenance.metadataSource)
                    LabeledContent("Licence", value: provenance.metadataLicense)
                    LabeledContent("Countries", value: "\(provenance.countryCount)")

                    Divider()

                    Text(provenance.attribution)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Atlas Desktop works entirely offline. It does not create accounts, contact any server, or collect analytics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    DisclosureGroup("How this data was prepared") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(provenance.transformations, id: \.self) { step in
                                Text("• \(step)")
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .font(.footnote)
                } else {
                    Text("Geography data has not loaded, so its credits are unavailable.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
    }

    private var rotationSpeedDescription: String {
        let degreesPerSecond = session.preferences.autoRotationDegreesPerSecond
        guard degreesPerSecond > 0 else { return "Stopped" }
        let seconds = 360 / degreesPerSecond
        return String(
            format: "%.1f° per second — one full turn every %@",
            degreesPerSecond,
            seconds >= 60
                ? String(format: "%.0f min %.0f s", (seconds / 60).rounded(.down), seconds.truncatingRemainder(dividingBy: 60))
                : String(format: "%.0f s", seconds)
        )
    }

    /// `GlobeSession` exposes intent-named setters rather than settable
    /// properties, so each control is bridged explicitly instead of
    /// binding straight into state.
    private func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}
