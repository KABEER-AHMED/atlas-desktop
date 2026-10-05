import SwiftUI
import AtlasDesktopCore
import AtlasGlobeRendering

/// The main window: globe, controls, and the information panel.
struct MainWindowView: View {
    let model: AppModel

    private var session: GlobeSession { model.session }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color(GlobeTheme.standard.space)

                switch session.loadState {
                case .loading:
                    LoadingView()
                case .failed(let error):
                    LoadFailureView(error: error)
                case .ready:
                    GlobeView(session: session)
                        .accessibilityLabel("Interactive globe")
                        .accessibilityHint("Drag to rotate, scroll to zoom, click a country to select it. Arrow keys rotate, plus and minus zoom.")
                }

                VStack {
                    Spacer()
                    GlobeControlsBar(model: model)
                        .padding(.bottom, 16)
                }
            }
            .frame(minWidth: 480, minHeight: 420)

            Divider()

            CountryFactsPanel(session: session)
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(Color(GlobeTheme.standard.space))
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading geography…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading geography data")
    }
}

/// Shown when the bundled data cannot be loaded.
///
/// FR-12: a missing or corrupt resource must produce something
/// actionable, not a blank globe. The error's own description, reason
/// and recovery suggestion are all surfaced.
private struct LoadFailureView: View {
    let error: GeographyError

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The globe could not be loaded", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(error.localizedDescription)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if let reason = error.failureReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
