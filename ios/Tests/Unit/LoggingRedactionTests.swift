@testable import SleepParalysisCompanion
import XCTest

final class LoggingRedactionTests: XCTestCase {
    func testSensitiveStringIsAlwaysRedacted() {
        let value = SensitiveLogValue("person@example.test")

        XCTAssertEqual(value.description, "<redacted>")
        XCTAssertFalse(value.description.contains("person@example.test"))
    }

    func testSensitiveStructuredValueIsAlwaysRedacted() {
        struct Payload: Sendable {
            let token: String
            let note: String
        }

        let value = SensitiveLogValue(
            Payload(token: "not-a-real-token", note: "private note")
        )

        XCTAssertEqual(value.description, "<redacted>")
        XCTAssertFalse(value.description.contains("private note"))
    }

    func testLogEventsContainOnlyFixedCodes() {
        let codes = [
            AppLogEvent.appActivated.rawValue,
            AppLogEvent.appDeactivated.rawValue,
            AppLogEvent.configurationUnavailable.rawValue,
            AppLogEvent.routeChanged.rawValue,
        ]

        XCTAssertEqual(Set(codes).count, codes.count)
        XCTAssertTrue(codes.allSatisfy { $0.range(of: "^[a-z_]+$", options: .regularExpression) != nil })
    }
}
