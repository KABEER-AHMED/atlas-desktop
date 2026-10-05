import Foundation

/// A stable, source-backed country identifier, per docs/ARCHITECTURE.md
/// ("Use stable source-backed identifiers, not display names, as keys")
/// and docs/DATA_AND_LICENSES.md ("Use ISO 3166-1 identifiers where
/// available").
///
/// Accepts both ISO 3166-1 alpha-2 (2 letters, e.g. "TR") and alpha-3
/// (3 letters, e.g. "TUR") — deliberately, not just alpha-2. Natural
/// Earth, this project's candidate geometry source
/// (docs/DATA_AND_LICENSES.md), keys its attribute tables primarily by
/// alpha-3 (`ISO_A3`/`ADM0_A3`). A 2-letter-only validator would
/// silently reject every real record from that pipeline in
/// Milestone 2. If a different final dataset turns out to be
/// alpha-2-only, narrow this back down then — but don't narrow it
/// before the real dataset is picked.
public struct CountryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (2...3).contains(normalized.count),
              normalized.unicodeScalars.allSatisfy(\.properties.isAlphabetic) else {
            return nil
        }

        self.rawValue = normalized
    }
}

extension CountryID: CustomStringConvertible {
    public var description: String { rawValue }
}
