@testable import SleepParalysisCompanion
import XCTest

final class PermissionStateTests: XCTestCase {
    func testPhase1CPermissionSeamDoesNotRequestOrAssumeAuthorization() async {
        let provider = Phase1CPermissionStateProvider()

        let state = await provider.state(for: .alarms)

        XCTAssertEqual(state, .notRequested)
    }

    func testPermissionRecoveryStatesAreFiniteAndDocumented() {
        XCTAssertEqual(
            Set(ContextualPermissionState.allCases),
            Set([.notRequested, .denied, .unsupported, .available])
        )
        XCTAssertEqual(ContextualPermissionKind.allCases, [.alarms])
    }
}
