import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class PersonalAlarmAudioPreparationTests: XCTestCase {
    func testPreparedFileNameIsDeterministicAndScopedToClipID() throws {
        let clipID = try XCTUnwrap(UUID(uuidString: "A1000000-0000-4000-8000-000000000001"))

        XCTAssertEqual(
            PersonalAlarmAudioContract.fileName(for: clipID),
            "SPCPersonalAlarm-a1000000-0000-4000-8000-000000000001.caf"
        )
        XCTAssertTrue(
            PersonalAlarmAudioContract.isPreparedFileName(
                "SPCPersonalAlarm-a1000000-0000-4000-8000-000000000001.caf"
            )
        )
    }

    func testPreparedFileNameRejectsPathTraversalAndOtherAssets() {
        XCTAssertFalse(PersonalAlarmAudioContract.isPreparedFileName("../alarm.caf"))
        XCTAssertFalse(PersonalAlarmAudioContract.isPreparedFileName("SPCWakeUpGentleLoop.caf"))
        XCTAssertFalse(PersonalAlarmAudioContract.isPreparedFileName("SPCPersonalAlarm-not-a-uuid.caf"))
    }

    func testAlarmKitOutputContractIsMonoPcm16CafAt44100Hz() {
        XCTAssertEqual(PersonalAlarmAudioContract.sampleRate, 44100)
        XCTAssertEqual(PersonalAlarmAudioContract.channelCount, 1)
        XCTAssertEqual(PersonalAlarmAudioContract.bitDepth, 16)
        XCTAssertEqual(PersonalAlarmAudioContract.fileExtension, "caf")
    }
}
