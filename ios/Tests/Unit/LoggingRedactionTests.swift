@testable import SleepParalysisCompanion
import XCTest

final class LoggingRedactionTests: XCTestCase {
    @MainActor
    func testSensitiveStringIsAlwaysRedacted() {
        let value = SensitiveLogValue("person@example.test")
        let description = value.description

        XCTAssertEqual(description, "<redacted>")
        XCTAssertFalse(description.contains("person@example.test"))
    }

    @MainActor
    func testSensitiveStructuredValueIsAlwaysRedacted() {
        struct Payload: Sendable {
            let token: String
            let note: String
        }

        let value = SensitiveLogValue(
            Payload(token: "not-a-real-token", note: "private note")
        )
        let description = value.description

        XCTAssertEqual(description, "<redacted>")
        XCTAssertFalse(description.contains("private note"))
    }

    func testLogEventsContainOnlyFixedCodes() {
        let codes = AppLogEvent.allCases.map(\.rawValue)

        XCTAssertEqual(Set(codes).count, codes.count)
        XCTAssertTrue(codes.allSatisfy { $0.range(of: "^[a-z_]+$", options: .regularExpression) != nil })

        let categories = AppLogCategory.allCases.map(\.rawValue)
        XCTAssertEqual(Set(categories).count, categories.count)
        XCTAssertTrue(categories.allSatisfy { $0.range(of: "^[a-z_]+$", options: .regularExpression) != nil })
    }
}
