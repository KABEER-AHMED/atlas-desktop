import Foundation

public struct CountryID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 2, normalized.unicodeScalars.allSatisfy(\.properties.isAlphabetic) else {
            return nil
        }

        self.rawValue = normalized
    }
}
