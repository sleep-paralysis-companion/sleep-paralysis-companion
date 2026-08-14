import Foundation
import GRDB

extension LocalDatabase {
    func activateAuthenticatedProfile(
        userID: UUID,
        provider: AuthenticationProvider,
        sessionExpiresAt: Date,
        now: Date
    ) throws -> LocalProfile {
        var result: LocalProfile?
        try write { database in
            if var existing = try LocalProfileRecord.order(Column("createdAt")).fetchOne(database) {
                if let accountUserID = existing.accountUserID, accountUserID != userID.uuidString {
                    throw AuthenticationError.wrongAccount
                }
                existing.accountUserID = userID.uuidString
                existing.ownership = ProfileOwnership.accountLinked.rawValue
                existing.accountLinkState = AccountLinkState.linked.rawValue
                existing.productNoticeVersion = ProductNotice.currentVersion
                existing.productNoticeSeenAt = now.timeIntervalSince1970
                try existing.update(database)
                if try AppSettingsRecord.fetchOne(database, key: existing.id) == nil {
                    guard let profileID = UUID(uuidString: existing.id) else {
                        throw LocalDatabaseError.corruptOrUnreadable
                    }
                    try AppSettingsRecord(
                        AppSettings(
                            profileID: profileID,
                            preferredGroundingAssetID: nil,
                            preferredModality: .audio,
                            hapticsEnabled: true,
                            lastSelectedHistoryPeriod: .thirtyDays,
                            diagnosticsEnabled: false,
                            defaultSleepSupport: .quickSleep,
                            defaultPostEpisodeSupport: .calmingAudio,
                            updatedAt: now,
                            revision: 1
                        )
                    ).insert(database)
                }
                try AccountBindingRecord(
                    profileID: existing.id,
                    userID: userID.uuidString,
                    provider: provider.rawValue,
                    maskedIdentifier: nil,
                    linkedAt: now.timeIntervalSince1970,
                    sessionExpiresAt: sessionExpiresAt.timeIntervalSince1970,
                    requiresReauthentication: false
                ).save(database)
                result = try existing.domainValue()
                return
            }

            let profile = LocalProfile(
                id: UUID(),
                createdAt: now,
                onboardingCompletedAt: nil,
                productNoticeVersion: ProductNotice.currentVersion,
                productNoticeSeenAt: now,
                ownership: .accountLinked,
                accountUserID: userID,
                accountLinkState: .linked,
                displayName: nil,
                revision: 1
            )
            try LocalProfileRecord(profile).insert(database)
            try AppSettingsRecord(
                AppSettings(
                    profileID: profile.id,
                    preferredGroundingAssetID: nil,
                    preferredModality: .audio,
                    hapticsEnabled: true,
                    lastSelectedHistoryPeriod: .thirtyDays,
                    diagnosticsEnabled: false,
                    defaultSleepSupport: .quickSleep,
                    defaultPostEpisodeSupport: .calmingAudio,
                    updatedAt: now,
                    revision: 1
                )
            ).insert(database)
            try AccountBindingRecord(
                profileID: profile.id.uuidString,
                userID: userID.uuidString,
                provider: provider.rawValue,
                maskedIdentifier: nil,
                linkedAt: now.timeIntervalSince1970,
                sessionExpiresAt: sessionExpiresAt.timeIntervalSince1970,
                requiresReauthentication: false
            ).insert(database)
            result = profile
        }
        guard let result else { throw LocalDatabaseError.writeFailed }
        return result
    }

    func markIntegratedOnboardingComplete(
        profileID: UUID,
        userID: UUID,
        completedAt: Date
    ) throws {
        try write { database in
            guard var profile = try LocalProfileRecord.fetchOne(database, key: profileID.uuidString),
                  profile.accountUserID == userID.uuidString
            else {
                throw AuthenticationError.wrongAccount
            }
            profile.onboardingCompletedAt = completedAt.timeIntervalSince1970
            try profile.update(database)
        }
    }
}
