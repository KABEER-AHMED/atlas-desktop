import SwiftUI
import AtlasDesktopCore

/// Keyboard-driven country selection (⌘F).
///
/// Selecting on the globe needs a pointer; this sheet makes the same
/// action reachable from the keyboard alone, which is what FR-11 asks
/// for beyond the mode toggles. Choosing a country selects it *and*
/// turns the globe to it, so the keyboard path ends in the same place
/// the pointer path does.
///
/// In learning mode the list hides country names, because a searchable
/// list of answers would defeat the mode; it offers the globe's own
/// identifiers instead.
struct CountryFinderView: View {
    let session: GlobeSession
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var highlighted: CountryID?

    private var matches: [Country] {
        guard let lookup = session.dataset?.lookup else { return [] }
        return Array(lookup.search(query).sorted { label(for: $0) < label(for: $1) }.prefix(200))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find a country")
                .font(.headline)

            TextField("Name or ISO code", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search countries by name or ISO code")

            if session.isLearningModeEnabled {
                Text("Learning mode is on, so names are hidden here. Search still works.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            List(matches, id: \.id, selection: $highlighted) { country in
                Button {
                    choose(country)
                } label: {
                    HStack {
                        Text(label(for: country))
                        Spacer()
                        Text(country.facts.displayIdentifier)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(for: country))
                .accessibilityHint("Selects this country and turns the globe to it")
            }
            .frame(height: 280)

            HStack {
                Text("\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Select") {
                    if let id = highlighted, let country = session.dataset?.lookup.country(id: id) {
                        choose(country)
                    } else if let first = matches.first {
                        choose(first)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(matches.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 380)
    }

    /// Identifiers stand in for names while learning mode is on.
    private func label(for country: Country) -> String {
        session.isLearningModeEnabled ? country.facts.displayIdentifier : country.facts.name
    }

    private func choose(_ country: Country) {
        session.select(country)
        session.focus(on: country)
        isPresented = false
    }
}
