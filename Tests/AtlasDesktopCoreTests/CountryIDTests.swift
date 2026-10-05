import XCTest
@testable import AtlasDesktopCore

final class CountryIDTests: XCTestCase {
    func testValidThreeLetterCodeIsAccepted() {
        XCTAssertNotNil(CountryID(rawValue: "TUR"))
        XCTAssertNotNil(CountryID(rawValue: "ind")) // case-insensitive
        XCTAssertEqual(CountryID(rawValue: "ind")?.rawValue, "IND")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(CountryID(rawValue: " TUR \n")?.rawValue, "TUR")
    }

    func testWrongLengthIsRejected() {
        XCTAssertNil(CountryID(rawValue: "TU"))
        XCTAssertNil(CountryID(rawValue: "TURK"))
        XCTAssertNil(CountryID(rawValue: ""))
    }

    func testNonLetterCharactersAreRejected() {
        XCTAssertNil(CountryID(rawValue: "TU1"))
        XCTAssertNil(CountryID(rawValue: "123"))
    }
}
