import Foundation

/// A stable, source-backed identifier for a country (ISO 3166-1 alpha-3),
/// per docs/ARCHITECTURE.md: "Use stable source-backed identifiers, not
/// display names, as keys."
public struct CountryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 3, trimmed.allSatisfy({ $0.isLetter }) else {
            return nil
        }
        self.rawValue = trimmed
    }
}

extension CountryID: CustomStringConvertible {
    public var description: String { rawValue }
}
