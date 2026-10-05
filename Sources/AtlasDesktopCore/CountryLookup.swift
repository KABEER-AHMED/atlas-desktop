import Foundation

/// Maps a coordinate to the country containing it.
///
/// A flat scan with a bounding-box prefilter: the 1:110m dataset has
/// 177 countries, so the prefilter rejects all but a handful per query
/// and a click costs well under a millisecond. A spatial index would be
/// added only if profiling showed this mattered (docs/ARCHITECTURE.md:
/// "Add spatial indexing only if profiling justifies it").
public struct CountryLookup: Sendable {
    private let countries: [Country]
    private let byID: [CountryID: Country]

    public init(countries: [Country]) {
        self.countries = countries
        self.byID = Dictionary(countries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public var all: [Country] { countries }
    public var count: Int { countries.count }

    public func country(id: CountryID) -> Country? { byID[id] }

    /// The country containing `coordinate`, or `nil` for open ocean.
    ///
    /// When coordinates fall inside more than one country's geometry —
    /// possible at a shared border vertex — the smaller country wins,
    /// so clicking Lesotho or the Vatican doesn't select the country
    /// surrounding it.
    public func country(at coordinate: Coordinate) -> Country? {
        var match: Country?
        for country in countries where country.geometry.containsPoint(coordinate) {
            if let current = match, current.geometry.relativeSize <= country.geometry.relativeSize {
                continue
            }
            match = country
        }
        return match
    }

    /// Case- and whitespace-insensitive search over names and
    /// identifiers, for the keyboard-accessible country list.
    public func search(_ query: String) -> [Country] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return countries }
        return countries.filter { country in
            let facts = country.facts
            return facts.name.lowercased().contains(needle)
                || (facts.longName?.lowercased().contains(needle) ?? false)
                || facts.id.rawValue.lowercased().hasPrefix(needle)
                || (facts.isoAlpha2?.lowercased() == needle)
                || (facts.isoAlpha3?.lowercased().hasPrefix(needle) ?? false)
        }
    }
}
