import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class AlarmScheduleSyncMappingTests: XCTestCase {
    func testAlarmScheduleOutboundPayloadContainsCompleteScheduleShape() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await database.createProfile(profile, settings: Phase1BFixture.settings())

        let schedule = AlarmSchedule(
            id: Phase1BFixture.entityID,
            profileID: profile.id,
            name: "Work nights",
            kind: .sleep,
            bedtimeHour: 22,
            bedtimeMinute: 30,
            wakeHour: 6,
            wakeMinute: 30,
            weekdaysMask: 0b0111_1111,
            bedtimeReminderLeadMinutes: 15,
            wakeReminderLeadMinutes: 10,
            finalWakeAlarmEnabled: true,
            wakeAudio: AlarmAudioSelection(
                reference: .catalog(assetID: "rain", version: 3),
                localFileName: "rain.caf"
            ),
            isEnabled: true,
            sortOrder: 4,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        let stored = try await database.saveAlarmSchedule(
            schedule,
            profileID: profile.id
        )
        let operation = SynchronizationOperation(
            id: Phase1BFixture.operationID,
            profileID: profile.id,
            entityType: .alarm,
            entityID: stored.id,
            operation: .upsert,
            idempotencyKey: Phase1BFixture.key,
            baseRevision: 0,
            localRevision: stored.revision,
            state: .pending,
            attemptCount: 0,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )

        let provider = LocalDatabaseOutboundPayloadProvider(database: database)
        let payload = try await provider.payload(
            for: operation,
            authenticatedUserID: Phase1BFixture.userID
        )
        guard case let .alarm(dto) = payload else {
            return XCTFail("Expected an alarm payload")
        }
        XCTAssertEqual(dto.id, stored.id)
        XCTAssertEqual(dto.ownerUserID, Phase1BFixture.userID)
        XCTAssertEqual(dto.scheduleName, "Work nights")
        XCTAssertEqual(dto.scheduleKind, "sleep")
        XCTAssertEqual(dto.sleepHour, 22)
        XCTAssertEqual(dto.sleepMinute, 30)
        XCTAssertEqual(dto.localHour, 6)
        XCTAssertEqual(dto.localMinute, 30)
        XCTAssertEqual(dto.weekdaysMask, 0b0111_1111)
        XCTAssertEqual(dto.bedtimeReminderLeadMinutes, 15)
        XCTAssertEqual(dto.prewakeLeadMinutes, 10)
        XCTAssertEqual(dto.wakeAudioKind, "catalog")
        XCTAssertEqual(dto.wakeAudioReference, "catalog:rain:3")
        XCTAssertEqual(dto.displayOrder, 4)
        XCTAssertEqual(dto.revision, stored.revision)
    }
}
