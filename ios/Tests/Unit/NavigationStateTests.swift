import XCTest
@testable import SleepParalysisCompanion

@MainActor
final class NavigationStateTests: XCTestCase {
    func testNavigationUsesTypedRouteValues() {
        let model = makeModel()

        model.send(.showFoundationDetails)

        XCTAssertEqual(model.path, [.foundationDetails])
    }

    func testNavigationPathCanBeRestoredDeterministically() {
        let model = makeModel()

        model.send(.setPath([.foundationDetails]))
        XCTAssertEqual(model.path, [.foundationDetails])

        model.send(.setPath([]))
        XCTAssertTrue(model.path.isEmpty)
    }

    private func makeModel() -> AppModel {
        AppModel(
            environment: .development,
            accessPolicy: AccessPolicy(),
            logger: RecordingLogger()
        )
    }
}

private struct RecordingLogger: PrivacySafeLogging {
    func record(_ event: AppLogEvent, category: AppLogCategory) {
        _ = event
        _ = category
    }
}
