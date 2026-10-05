import SwiftUI
import AtlasDesktopCore

/// Placeholder UI. Replaced by the globe screen in Milestone 3+.
/// Exists only to confirm the app shell launches and the
/// AtlasDesktopCore module links correctly (Milestone 0 exit gate).
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Atlas Desktop")
                .font(.title2)
                .bold()
            Text("Milestone 0 bootstrap — renderer and data pipeline not yet implemented.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let sampleID = CountryID(rawValue: "TUR") {
                Text("Core module linked (sample ID: \(sampleID.rawValue))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(40)
        .frame(minWidth: 420, minHeight: 280)
    }
}

#Preview {
    ContentView()
}
