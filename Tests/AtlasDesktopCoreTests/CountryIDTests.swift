import Testing
@testable import AtlasDesktopCore

struct CountryIDTests {
    @Test func acceptsTwoLetterAlphabeticCodes() {
        #expect(CountryID(rawValue: "us")?.rawValue == "US")
        #expect(CountryID(rawValue: " JP ")?.rawValue == "JP")
    }

    @Test func acceptsThreeLetterAlphabeticCodes() {
        // Natural Earth (docs/DATA_AND_LICENSES.md's candidate source)
        // keys its attribute tables by ISO 3166-1 alpha-3 — this must
        // not be rejected once Milestone 2 wires in real data.
        #expect(CountryID(rawValue: "tur")?.rawValue == "TUR")
        #expect(CountryID(rawValue: " IND ")?.rawValue == "IND")
    }

    @Test func rejectsNonAlphabeticOrWrongLengthCodes() {
        #expect(CountryID(rawValue: "U") == nil)
        #expect(CountryID(rawValue: "USAA") == nil)
        #expect(CountryID(rawValue: "U1") == nil)
    }
}
