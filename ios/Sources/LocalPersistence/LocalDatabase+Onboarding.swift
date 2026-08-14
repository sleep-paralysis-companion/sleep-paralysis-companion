import Foundation
import GRDB

extension LocalDatabase {
    func activeProfile() throws -> LocalProfile? {
        try pool.read { database in
            try LocalProfileRecord
                .order(Column("createdAt"))
                .fetchOne(database)?
                .domainValue()
        }
    }

    func createGuestProfileIfAbsent(_ value: OnboardingProfile) throws -> LocalProfile {
        if let existing = try activeProfile() {
            return existing
        }
        guard let completedAt = value.onboardingCompletedAt,
              !value.productNoticeVersion.isEmpty,
              value.productNoticeVersion.count <= 100
        else {
            throw LocalDatabaseError.constraintViolation
        }

        let profile = LocalProfile(
            id: value.localProfileID,
            createdAt: value.profileCreatedAt,
            onboardingCompletedAt: completedAt,
            productNoticeVersion: value.productNoticeVersion,
            productNoticeSeenAt: value.productNoticeSeenAt,
            ownership: .guestLocal,
            accountUserID: nil,
            accountLinkState: .localOnly,
            displayName: nil,
            revision: 1
        )
        try write { database in
            try LocalProfileRecord(profile).insert(database)
        }
        guard let stored = try activeProfile() else {
            throw LocalDatabaseError.writeFailed
        }
        return stored
    }

    func markProductNoticeSeen(version: String, seenAt: Date) throws -> LocalProfile {
        guard !version.isEmpty, version.count <= 100,
              var profile = try activeProfile()
        else {
            throw LocalDatabaseError.constraintViolation
        }
        profile.productNoticeVersion = version
        profile.productNoticeSeenAt = seenAt
        try write { database in
            try LocalProfileRecord(profile).update(database)
        }
        return profile
    }
}
