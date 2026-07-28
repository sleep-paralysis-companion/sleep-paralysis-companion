import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class OnboardingPersistenceTests: XCTestCase {
    func testAtomicGuestCreationStoresOnlyProfileAndIsIdempotent() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        let input = Phase1CFixture.profile()

        let first = try await database.createGuestProfileIfAbsent(input)
        let secondInput = OnboardingProfile(
            localProfileID: UUID(),
            profileCreatedAt: Phase1CFixture.now.addingTimeInterval(60),
            productNoticeVersion: "different",
            productNoticeSeenAt: Phase1CFixture.now.addingTimeInterval(60),
            onboardingCompletedAt: Phase1CFixture.now.addingTimeInterval(60)
        )
        let second = try await database.createGuestProfileIfAbsent(secondInput)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.id, Phase1CFixture.profileID)
        XCTAssertEqual(first.ownership, .guestLocal)
        XCTAssertNil(first.accountUserID)
        XCTAssertEqual(first.accountLinkState, .localOnly)
        let settings = try await database.settings(profileID: first.id)
        XCTAssertNil(settings)
    }

    func testFailedGuestCreationLeavesNoPartialProfile() async throws {
        let database = try LocalDatabase(
            path: temporaryDatabasePath(),
            writeFault: FailingLocalWrite()
        )

        await XCTAssertThrowsErrorAsync {
            try await database.createGuestProfileIfAbsent(Phase1CFixture.profile())
        }

        let profile = try await database.activeProfile()
        XCTAssertNil(profile)
    }

    func testInvalidIncompleteCreationLeavesNoProfile() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())

        await XCTAssertThrowsErrorAsync {
            try await database.createGuestProfileIfAbsent(
                Phase1CFixture.profile(completed: false)
            )
        }

        let profile = try await database.activeProfile()
        XCTAssertNil(profile)
    }

    func testSupersededNoticeUpdatesExistingProfileWithoutChangingIdentity() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        let old = Phase1CFixture.profile(noticeVersion: "old")
        _ = try await database.createGuestProfileIfAbsent(old)
        let seenAt = Phase1CFixture.now.addingTimeInterval(60)

        let updated = try await database.markProductNoticeSeen(
            version: ProductNotice.currentVersion,
            seenAt: seenAt
        )

        XCTAssertEqual(updated.id, old.localProfileID)
        XCTAssertEqual(updated.createdAt, old.profileCreatedAt)
        XCTAssertEqual(updated.onboardingCompletedAt, old.onboardingCompletedAt)
        XCTAssertEqual(updated.productNoticeVersion, ProductNotice.currentVersion)
        XCTAssertEqual(updated.productNoticeSeenAt, seenAt)
    }

    func testInterruptedLegacyProfileRoutesAsIncompleteUntilExplicitCompletion() async throws {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        let partial = LocalProfile(
            id: Phase1CFixture.profileID,
            createdAt: Phase1CFixture.now,
            onboardingCompletedAt: nil,
            productNoticeVersion: ProductNotice.currentVersion,
            productNoticeSeenAt: Phase1CFixture.now,
            ownership: .guestLocal,
            accountUserID: nil,
            accountLinkState: .localOnly
        )
        try await database.saveProfile(partial)

        let stored = try await database.activeProfile()

        XCTAssertNil(stored?.onboardingCompletedAt)
        XCTAssertEqual(stored?.id, Phase1CFixture.profileID)
    }
}
