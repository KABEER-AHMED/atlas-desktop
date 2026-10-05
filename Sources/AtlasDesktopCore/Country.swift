import Foundation

/// A country's facts as they exist in the bundled dataset.
///
/// Optional fields are optional on purpose: Natural Earth genuinely
/// lacks an ISO code for a handful of entries (Kosovo, Somaliland,
/// Northern Cyprus) and a capital for others (Antarctica, Western
/// Sahara). Those gaps are surfaced in the UI as "Not in dataset"
/// rather than filled in from another source — see
/// docs/DATA_AND_LICENSES.md.
public struct CountryFacts: Equatable, Sendable, Codable {
    /// Stable primary key. Natural Earth's `ADM0_A3`, which is present
    /// for every feature, unlike `ISO_A3`.
    public let id: CountryID
    /// Short display name (`NAME`).
    public let name: String
    /// Formal/long name (`NAME_LONG`) when it differs from `name`.
    public let longName: String?
    /// ISO 3166-1 alpha-2, when the dataset has one.
    public let isoAlpha2: String?
    /// ISO 3166-1 alpha-3, when the dataset has one.
    public let isoAlpha3: String?
    public let continent: String?
    public let region: String?
    public let subregion: String?
    /// Capital cities. More than one is legitimate (South Africa has
    /// three, Bolivia two); an empty array means the dataset has none.
    public let capitals: [String]

    public init(
        id: CountryID,
        name: String,
        longName: String? = nil,
        isoAlpha2: String? = nil,
        isoAlpha3: String? = nil,
        continent: String? = nil,
        region: String? = nil,
        subregion: String? = nil,
        capitals: [String] = []
    ) {
        self.id = id
        self.name = name
        self.longName = longName
        self.isoAlpha2 = isoAlpha2
        self.isoAlpha3 = isoAlpha3
        self.continent = continent
        self.region = region
        self.subregion = subregion
        self.capitals = capitals
    }

    /// The identifier to show the user: a real ISO code when the
    /// dataset has one, otherwise the dataset's own key, labelled as
    /// such by the UI.
    public var displayIdentifier: String { isoAlpha3 ?? id.rawValue }
    public var hasISOIdentifier: Bool { isoAlpha3 != nil }
}

/// Facts plus geometry plus a label anchor.
public struct Country: Equatable, Sendable {
    public let facts: CountryFacts
    public let geometry: CountryGeometry
    /// Where the country's label is drawn. Natural Earth's
    /// `LABEL_X`/`LABEL_Y` when available (hand-placed by the dataset's
    /// cartographers, so better than a centroid for shapes like Chile),
    /// otherwise the bounding-box centre of the largest polygon.
    public let labelAnchor: Coordinate

    public var id: CountryID { facts.id }

    public init(facts: CountryFacts, geometry: CountryGeometry, labelAnchor: Coordinate) {
        self.facts = facts
        self.geometry = geometry
        self.labelAnchor = labelAnchor
    }
}
