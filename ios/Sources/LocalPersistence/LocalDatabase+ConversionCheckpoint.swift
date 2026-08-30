import Foundation
import GRDB

extension LocalDatabase {
    func beginConversion(_ checkpoint: ConversionCheckpoint) throws {
        try write { database in
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: checkpoint.profileID.uuidString
            ), profile.accountUserID == nil else {
                throw AuthenticationError.wrongAccount
            }
            profile.accountLinkState = AccountLinkState.authenticating.rawValue
            try profile.update(database)
            try ConversionCheckpointRecord(
                conversionID: checkpoint.conversionID.uuidString,
                profileID: checkpoint.profileID.uuidString,
                expectedUserID: checkpoint.expectedUserID.uuidString,
                state: checkpoint.state.rawValue,
                mergeChoice: checkpoint.mergeChoice?.rawValue,
                startedAt: checkpoint.startedAt.timeIntervalSince1970,
                updatedAt: checkpoint.updatedAt.timeIntervalSince1970
            ).insert(database)
        }
    }

    func saveConversionCheckpoint(_ checkpoint: ConversionCheckpoint) throws {
        try write { database in
            try ConversionCheckpointRecord(
                conversionID: checkpoint.conversionID.uuidString,
                profileID: checkpoint.profileID.uuidString,
                expectedUserID: checkpoint.expectedUserID.uuidString,
                state: checkpoint.state.rawValue,
                mergeChoice: checkpoint.mergeChoice?.rawValue,
                startedAt: checkpoint.startedAt.timeIntervalSince1970,
                updatedAt: checkpoint.updatedAt.timeIntervalSince1970
            ).save(database)
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: checkpoint.profileID.uuidString
            ) else {
                throw LocalDatabaseError.constraintViolation
            }
            profile.accountLinkState = checkpoint.state.rawValue
            try profile.update(database)
        }
    }

    func conversionCheckpoint(profileID: UUID) throws -> ConversionCheckpoint? {
        try pool.read { database in
            guard let record = try ConversionCheckpointRecord.fetchOne(
                database,
                sql: "SELECT * FROM conversion_checkpoints WHERE profileID = ?",
                arguments: [profileID.uuidString]
            ),
                let conversionID = UUID(uuidString: record.conversionID),
                let storedProfileID = UUID(uuidString: record.profileID),
                let expectedUserID = UUID(uuidString: record.expectedUserID),
                let state = AccountLinkState(rawValue: record.state)
            else {
                return nil
            }
            return ConversionCheckpoint(
                conversionID: conversionID,
                profileID: storedProfileID,
                expectedUserID: expectedUserID,
                state: state,
                mergeChoice: record.mergeChoice.flatMap(GuestMergeChoice.init(rawValue:)),
                startedAt: Date(timeIntervalSince1970: record.startedAt),
                updatedAt: Date(timeIntervalSince1970: record.updatedAt)
            )
        }
    }

    func finalizeConversion(binding: AccountBinding, conversionID: UUID) throws {
        try write { database in
            guard let checkpoint = try ConversionCheckpointRecord.fetchOne(
                database,
                key: conversionID.uuidString
            ),
                checkpoint.expectedUserID == binding.userID.uuidString,
                checkpoint.profileID == binding.profileID.uuidString,
                var profile = try LocalProfileRecord.fetchOne(
                    database,
                    key: binding.profileID.uuidString
                )
            else {
                throw AuthenticationError.wrongAccount
            }
            profile.accountUserID = binding.userID.uuidString
            profile.ownership = ProfileOwnership.accountLinked.rawValue
            profile.accountLinkState = AccountLinkState.linked.rawValue
            try profile.update(database)
            try AccountBindingRecord(
                profileID: binding.profileID.uuidString,
                userID: binding.userID.uuidString,
                provider: binding.provider.rawValue,
                maskedIdentifier: binding.maskedIdentifier,
                linkedAt: binding.linkedAt.timeIntervalSince1970,
                sessionExpiresAt: binding.sessionExpiresAt.timeIntervalSince1970,
                requiresReauthentication: binding.requiresReauthentication
            ).save(database)
            _ = try ConversionCheckpointRecord.deleteOne(database, key: conversionID.uuidString)
        }
    }

    func cancelConversion(profileID: UUID) throws {
        try write { database in
            guard var profile = try LocalProfileRecord.fetchOne(
                database,
                key: profileID.uuidString
            ), profile.accountUserID == nil else {
                throw AuthenticationError.wrongAccount
            }
            profile.ownership = ProfileOwnership.guestLocal.rawValue
            profile.accountLinkState = AccountLinkState.localOnly.rawValue
            try profile.update(database)
            _ = try ConversionCheckpointRecord
                .filter(Column("profileID") == profileID.uuidString)
                .deleteAll(database)
        }
    }
}
