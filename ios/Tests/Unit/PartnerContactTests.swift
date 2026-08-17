import XCTest
@testable import SleepParalysisCompanion

final class PartnerContactTests: XCTestCase {
    func testNormalizesDisplayNameAndPhoneNumber() {
        let contact = PartnerContact(name: "  Alex  ", phoneNumber: "+1 (555) 123-4567")

        XCTAssertEqual(contact?.name, "Alex")
        XCTAssertEqual(contact?.phoneNumber, "+15551234567")
    }

    func testRejectsInvalidPhoneNumberAndOverlongName() {
        XCTAssertNil(PartnerContact(name: "Alex", phoneNumber: "12345"))
        XCTAssertNil(PartnerContact(name: String(repeating: "x", count: 81), phoneNumber: "1234567"))
        XCTAssertNil(PartnerContact(name: "Alex", phoneNumber: "555CALL"))
    }

    func testBuildsPhoneURLForExplicitCallAction() {
        let contact = PartnerContact(name: nil, phoneNumber: "+15551234567")

        XCTAssertEqual(contact?.phoneURL?.scheme, "tel")
        XCTAssertEqual(contact?.phoneURL?.absoluteString, "tel:+15551234567")
    }
}
