import Foundation

/// Facts shown in the country facts panel. Fields are optional because
/// not every source dataset has complete data for every territory —
/// per docs/ARCHITECTURE.md milestone 4: "Show country name, capital
/// when available, region/continent, and identifier when available."
public struct CountryMetadata: Hashable, Codable, Sendable {
    public let id: CountryID
    public let name: String
    public let capital: String?
    public let region: String?
    public let continent: String?

    public init(
        id: CountryID,
        name: String,
        capital: String? = nil,
        region: String? = nil,
        continent: String? = nil
    ) {
        self.id = id
        self.name = name
        self.capital = capital
        self.region = region
        self.continent = continent
    }
}
