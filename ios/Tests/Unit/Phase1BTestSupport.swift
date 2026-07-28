import Foundation
import os
@testable import SleepParalysisCompanion

struct FixedClock: Phase1BClock {
    let value: Date

    func now() -> Date {
        value
    }
}

struct FixedIdentifierGenerator: IdentifierGenerating {
    let value: UUID

    func next() -> UUID {
        value
    }
}

struct FixedUnitRandom: UnitIntervalRandom {
    let value: Double

    func next() -> Double {
        value
    }
}

struct FixedSecureRandom: SecureRandomBytes {
    let byte: UInt8

    func bytes(count: Int) throws -> [UInt8] {
        [UInt8](repeating: byte, count: count)
    }
}

final class LockedKeychain: KeychainClient {
    private let storage = OSAllocatedUnfairLock(initialState: [String: Data]())
    private let failure: AuthenticationError?

    init(failure: AuthenticationError? = nil) {
        self.failure = failure
    }

    func read(service: String, account: String) throws -> Data? {
        if let failure {
            throw failure
        }
        return storage.withLock { $0["\(service):\(account)"] }
    }

    func write(_ data: Data, service: String, account: String) throws {
        if let failure {
            throw failure
        }
        storage.withLock { $0["\(service):\(account)"] = data }
    }

    func delete(service: String, account: String) throws {
        if let failure {
            throw failure
        }
        storage.withLock { _ = $0.removeValue(forKey: "\(service):\(account)") }
    }
}

struct FailingLocalWrite: LocalWriteFaultInjecting {
    func beforeWrite() throws {
        throw CocoaError(.fileWriteOutOfSpace)
    }
}

enum Phase1BFixture {
    static let now = Date(timeIntervalSince1970: 1_753_660_800)
    static let profileID = uuid("11111111-1111-4111-8111-111111111111")
    static let userID = uuid("22222222-2222-4222-8222-222222222222")
    static let entityID = uuid("33333333-3333-4333-8333-333333333333")
    static let operationID = uuid("44444444-4444-4444-8444-444444444444")
    static let key = uuid("55555555-5555-4555-8555-555555555555")

    static func profile() -> LocalProfile {
        LocalProfile(
            id: profileID,
            createdAt: now,
            onboardingCompletedAt: now,
            productNoticeVersion: "v1",
            productNoticeSeenAt: now,
            ownership: .guestLocal,
            accountUserID: nil,
            accountLinkState: .localOnly
        )
    }

    static func settings(revision: Int64 = 1) -> AppSettings {
        AppSettings(
            profileID: profileID,
            preferredGroundingAssetID: nil,
            preferredModality: .silent,
            hapticsEnabled: false,
            lastSelectedHistoryPeriod: .sevenDays,
            diagnosticsEnabled: false,
            updatedAt: now,
            revision: revision
        )
    }

    static func checkIn(revision: Int64 = 1, note: String? = "synthetic") -> SubmittedCheckIn {
        SubmittedCheckIn(
            id: entityID,
            profileID: profileID,
            reportedForLocalDate: "2026-07-27",
            reportedTimezoneID: "Asia/Calcutta",
            occurrence: .yes,
            perceivedIntensity: .mild,
            presentState: .fineNow,
            note: note,
            createdAt: now,
            updatedAt: now,
            revision: revision,
            deletedAt: nil
        )
    }

    static func session(userID: UUID = userID) -> AuthenticationSessionMaterial {
        AuthenticationSessionMaterial(
            userID: userID,
            provider: .apple,
            accessToken: "synthetic-access",
            refreshToken: "synthetic-refresh",
            expiresAt: now.addingTimeInterval(3600)
        )
    }

    static func operation(
        state: SynchronizationState = .pending,
        attemptCount: Int = 0
    ) -> SynchronizationOperation {
        SynchronizationOperation(
            id: operationID,
            profileID: profileID,
            entityType: .checkIn,
            entityID: entityID,
            operation: .upsert,
            idempotencyKey: key,
            baseRevision: 0,
            localRevision: 1,
            state: state,
            attemptCount: attemptCount,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    static func uuid(_ value: String) -> UUID {
        guard let identifier = UUID(uuidString: value) else {
            fatalError("Invalid deterministic test UUID: \(value)")
        }
        return identifier
    }
}

func temporaryDatabasePath(_ name: String = UUID().uuidString) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(name).sqlite")
        .path
}
