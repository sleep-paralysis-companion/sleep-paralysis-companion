import XCTest
@testable import SleepParalysisCompanion

final class DesignTokenTests: XCTestCase {
    func testCriticalControlsMeetMinimumTouchTarget() {
        XCTAssertGreaterThanOrEqual(AppSpacing.minimumControl, 44)
    }

    func testReducedMotionRemovesDecorativeDuration() {
        XCTAssertEqual(AppMotion.standardDuration(reduceMotion: true), 0)
        XCTAssertGreaterThan(AppMotion.standardDuration(reduceMotion: false), 0)
    }

    func testAccessibilityTextUsesExpandedVerticalSpacing() {
        XCTAssertGreaterThan(
            AppAccessibility.verticalSpacing(for: .accessibility3),
            AppAccessibility.verticalSpacing(for: .large)
        )
    }
}
