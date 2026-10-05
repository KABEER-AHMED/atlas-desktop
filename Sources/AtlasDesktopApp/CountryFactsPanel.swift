import SwiftUI
import AtlasDesktopCore

/// The country information panel.
///
/// Three states, all of which matter: nothing selected (a useful empty
/// state rather than a blank box), a selection with its facts, and a
/// selection in learning mode with the facts withheld until the user
/// asks for them.
///
/// Facts the dataset does not have are shown as “Not in dataset”
/// instead of being omitted silently or filled in from elsewhere — the
/// user can tell the difference between "no capital recorded" and a bug.
struct CountryFactsPanel: View {
    let session: GlobeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().padding(.vertical, 12)

            if let country = session.selectedCountry {
                if session.areFactsVisible {
                    facts(for: country)
                } else {
                    hiddenAnswer
                }
            } else {
                emptyState
            }

            Spacer(minLength: 12)

            if let provenance = session.dataset?.provenance {
                attribution(provenance)
            }
        }
        .padding(18)
        .frame(width: 290)
        .background(.regularMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Country")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityHidden(true)

            Text(headerTitle)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(headerAccessibilityLabel)
        }
    }

    private var headerTitle: String {
        guard let country = session.selectedCountry else { return "Nothing selected" }
        return session.areFactsVisible ? country.facts.name : "Hidden"
    }

    private var headerAccessibilityLabel: String {
        guard let country = session.selectedCountry else { return "No country selected" }
        return session.areFactsVisible
            ? "Selected country: \(country.facts.name)"
            : "A country is selected. Its name is hidden in learning mode."
    }

    private func facts(for country: Country) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let longName = country.facts.longName {
                FactRow(label: "Formal name", value: longName)
            }
            FactRow(label: capitalLabel(for: country), value: capitalValue(for: country))
            FactRow(label: "Continent", value: country.facts.continent)
            FactRow(label: "Region", value: country.facts.subregion ?? country.facts.region)
            FactRow(
                label: country.facts.hasISOIdentifier ? "ISO 3166-1" : "Dataset identifier",
                value: identifierValue(for: country),
                // The identifier is a code, so it is read out
                // character by character rather than as a word.
                accessibilityValue: identifierAccessibilityValue(for: country)
            )

            if session.isLearningModeEnabled {
                Button("Hide Answer") { session.hideAnswer() }
                    .buttonStyle(.link)
                    .accessibilityHint("Hides this country’s facts again while keeping it selected")
            }
        }
    }

    private var hiddenAnswer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learning mode is on. A country is selected and its facts are hidden.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Reveal Answer") { session.revealAnswer() }
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityHint("Shows the selected country’s name and facts")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Click a country on the globe to see its name, capital, region and identifier.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if session.loadState == .ready, let count = session.dataset?.countries.count {
                Text("\(count) countries and territories loaded.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func capitalLabel(for country: Country) -> String {
        country.facts.capitals.count > 1 ? "Capitals" : "Capital"
    }

    private func capitalValue(for country: Country) -> String? {
        country.facts.capitals.isEmpty ? nil : country.facts.capitals.joined(separator: ", ")
    }

    private func identifierValue(for country: Country) -> String {
        guard let alpha3 = country.facts.isoAlpha3 else {
            // Kosovo, Somaliland and Northern Cyprus have no assigned
            // ISO code; the dataset's own key is shown and labelled as
            // such rather than presented as an ISO code.
            return "\(country.facts.id.rawValue) (no ISO code assigned)"
        }
        if let alpha2 = country.facts.isoAlpha2 {
            return "\(alpha3) · \(alpha2)"
        }
        return alpha3
    }

    private func identifierAccessibilityValue(for country: Country) -> String {
        let spelled = { (code: String) in code.map(String.init).joined(separator: " ") }
        guard let alpha3 = country.facts.isoAlpha3 else {
            return "\(spelled(country.facts.id.rawValue)), no ISO code assigned"
        }
        if let alpha2 = country.facts.isoAlpha2 {
            return "\(spelled(alpha3)), \(spelled(alpha2))"
        }
        return spelled(alpha3)
    }

    private func attribution(_ provenance: DatasetProvenance) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider().padding(.bottom, 8)
            Text(provenance.attribution)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One label/value pair. Missing values are stated, not hidden.
private struct FactRow: View {
    let label: String
    let value: String?
    var accessibilityValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value ?? "Not in dataset")
                .font(.system(size: 14))
                .foregroundStyle(value == nil ? .tertiary : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue ?? value ?? "Not in dataset")
    }
}
