import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class LegalSupportTests: XCTestCase {
    func testPublicLegalAndSupportURLsUseTheCanonicalValues() {
        XCTAssertEqual(LegalSupport.privacyURL.absoluteString, "https://sleepparalysis.app/privacy")
        XCTAssertEqual(LegalSupport.termsURL.absoluteString, "https://sleepparalysis.app/terms")
        XCTAssertEqual(LegalSupport.supportURL.absoluteString, "https://sleepparalysis.app/support")
        XCTAssertEqual(
            LegalSupport.accountDeletionURL.absoluteString,
            "https://sleepparalysis.app/delete-account"
        )
        XCTAssertEqual(LegalSupport.supportEmail, "founder@sleepparalysis.app")
        XCTAssertEqual(LegalSupport.supportEmailURL.absoluteString, "mailto:founder@sleepparalysis.app")
    }

    func testFounderIdentityAndSafetyCopyRemainCanonical() {
        XCTAssertEqual(LegalSupport.founderName, "Preshit Rakshe")
        XCTAssertTrue(HelpLegalCopy.productBoundary.contains("nonmedical wellness companion"))
        XCTAssertTrue(HelpLegalCopy.productBoundary.contains("not an emergency service"))
        XCTAssertTrue(HelpLegalCopy.manualEpisodeBoundary.contains("never automatically infers an episode"))
        XCTAssertEqual(HelpLegalCopy.personalAudioBoundary, "Personal audio remains on this device.")
        XCTAssertTrue(HelpLegalCopy.emergencyBoundary.contains("does not contact emergency services"))
    }
}
