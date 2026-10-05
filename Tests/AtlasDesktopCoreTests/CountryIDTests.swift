import Testing
@testable import AtlasDesktopCore

struct CountryIDTests {
    @Test func acceptsTwoLetterAlphabeticCodes() {
        #expect(CountryID(rawValue: "us")?.rawValue == "US")
        #expect(CountryID(rawValue: " JP ")?.rawValue == "JP")
    }

    @Test func rejectsNonAlphabeticOrWrongLengthCodes() {
        #expect(CountryID(rawValue: "U") == nil)
        #expect(CountryID(rawValue: "USA") == nil)
        #expect(CountryID(rawValue: "U1") == nil)
    }
}
