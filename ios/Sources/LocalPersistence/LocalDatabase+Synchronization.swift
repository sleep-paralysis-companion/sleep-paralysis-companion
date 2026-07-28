import Foundation
import GRDB

extension LocalDatabase {
    func enqueue(_ operation: SynchronizationOperation) throws {
        try write { try SynchronizationOperationRecord(operation).insert($0, onConflict: .ignore) }
    }

    func claimNextOperation(profileID: UUID, now: Date) throws -> SynchronizationOperation? {
        try pool.write { database in
            guard var record = try SynchronizationOperationRecord.fetchOne(
                database,
                sql: """
                SELECT * FROM sync_operations
                WHERE profileID = ?
                  AND state IN ('pending', 'failedRecoverable')
                  AND (nextAttemptAt IS NULL OR nextAttemptAt <= ?)
                  AND NOT EXISTS (
                    SELECT 1 FROM sync_operations inflight
                    WHERE inflight.profileID = sync_operations.profileID
                      AND inflight.entityType = sync_operations.entityType
                      AND inflight.entityID = sync_operations.entityID
                      AND inflight.state = 'syncing'
                  )
                ORDER BY createdAt, id
                LIMIT 1
                """,
                arguments: [profileID.uuidString, now.timeIntervalSince1970]
            ) else {
                return nil
            }
            record.state = SynchronizationState.syncing.rawValue
            record.attemptCount += 1
            record.updatedAt = now.timeIntervalSince1970
            try record.update(database)
            return try record.domainValue()
        }
    }

    func saveOperation(_ operation: SynchronizationOperation) throws {
        try write { try SynchronizationOperationRecord(operation).update($0) }
    }

    func acknowledgeRemoteMutation(
        operation: SynchronizationOperation,
        acknowledgment: RemoteMutationAcknowledgment
    ) throws {
        guard acknowledgment.idempotencyKey == operation.idempotencyKey,
              acknowledgment.entityID == operation.entityID,
              acknowledgment.acceptedRevision == operation.localRevision
        else {
            throw LocalDatabaseError.constraintViolation
        }

        try write { database in
            guard var operationRecord = try SynchronizationOperationRecord.fetchOne(
                database,
                key: operation.id.uuidString
            ),
                operationRecord.profileID == operation.profileID.uuidString,
                operationRecord.entityType == operation.entityType.rawValue,
                operationRecord.entityID == operation.entityID.uuidString
            else {
                throw LocalDatabaseError.constraintViolation
            }

            operationRecord.state = operation.state.rawValue
            operationRecord.attemptCount = operation.attemptCount
            operationRecord.nextAttemptAt = operation.nextAttemptAt?.timeIntervalSince1970
            operationRecord.lastErrorCategory = operation.lastErrorCategory?.rawValue
            operationRecord.updatedAt = operation.updatedAt.timeIntervalSince1970
            try operationRecord.update(database)

            try EntityRevisionRecord(
                profileID: operation.profileID.uuidString,
                entityType: operation.entityType.rawValue,
                entityID: operation.entityID.uuidString,
                localRevision: operation.localRevision,
                acknowledgedRemoteRevision: acknowledgment.acceptedRevision,
                lastRemoteMutationID: acknowledgment.serverMutationID.uuidString
            ).save(database)

            if operation.entityType == .tombstone {
                guard let acknowledgedAt = acknowledgment.acknowledgedAt,
                      let purgeAfter = acknowledgment.purgeAfter,
                      purgeAfter >= acknowledgedAt,
                      var tombstone = try DeletionTombstoneRecord.fetchOne(
                          database,
                          key: operation.entityID.uuidString
                      ),
                      tombstone.profileID == operation.profileID.uuidString
                else {
                    throw LocalDatabaseError.constraintViolation
                }
                tombstone.acknowledgedAt = acknowledgedAt.timeIntervalSince1970
                tombstone.purgeAfter = purgeAfter.timeIntervalSince1970
                try tombstone.update(database)
            }
        }
    }

    func operations(profileID: UUID) throws -> [SynchronizationOperation] {
        try pool.read { database in
            try SynchronizationOperationRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("createdAt"))
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    func saveEntityRevision(_ revision: EntityRevision) throws {
        guard revision.localRevision > 0 else {
            throw Phase1BValidationError.invalidRevision
        }
        try write { database in
            try EntityRevisionRecord(
                profileID: revision.profileID.uuidString,
                entityType: revision.entityType.rawValue,
                entityID: revision.entityID.uuidString,
                localRevision: revision.localRevision,
                acknowledgedRemoteRevision: revision.acknowledgedRemoteRevision,
                lastRemoteMutationID: revision.lastRemoteMutationID?.uuidString
            ).save(database)
        }
    }

    func entityRevision(
        profileID: UUID,
        entityType: SyncEntityType,
        entityID: UUID
    ) throws -> EntityRevision? {
        try pool.read { database in
            guard let record = try EntityRevisionRecord.fetchOne(
                database,
                key: [
                    "profileID": profileID.uuidString,
                    "entityType": entityType.rawValue,
                    "entityID": entityID.uuidString,
                ]
            ) else {
                return nil
            }
            return EntityRevision(
                profileID: profileID,
                entityType: entityType,
                entityID: entityID,
                localRevision: record.localRevision,
                acknowledgedRemoteRevision: record.acknowledgedRemoteRevision,
                lastRemoteMutationID: record.lastRemoteMutationID.flatMap(UUID.init(uuidString:))
            )
        }
    }

    func tombstones(profileID: UUID) throws -> [DeletionTombstone] {
        try pool.read { database in
            try DeletionTombstoneRecord
                .filter(Column("profileID") == profileID.uuidString)
                .order(Column("deletedAt"))
                .fetchAll(database)
                .compactMap { record in
                    guard let id = UUID(uuidString: record.id),
                          let entityID = UUID(uuidString: record.entityID),
                          let entityType = SyncEntityType(rawValue: record.entityType)
                    else {
                        return nil
                    }
                    return DeletionTombstone(
                        id: id,
                        profileID: profileID,
                        entityType: entityType,
                        entityID: entityID,
                        deletedRevision: record.deletedRevision,
                        deletedAt: Date(timeIntervalSince1970: record.deletedAt),
                        acknowledgedAt: record.acknowledgedAt.map(Date.init(timeIntervalSince1970:)),
                        purgeAfter: Date(timeIntervalSince1970: record.purgeAfter)
                    )
                }
        }
    }

    func tombstone(id: UUID, profileID: UUID) throws -> DeletionTombstone? {
        try pool.read { database in
            guard let record = try DeletionTombstoneRecord.fetchOne(
                database,
                key: id.uuidString
            ),
                record.profileID == profileID.uuidString,
                let entityID = UUID(uuidString: record.entityID),
                let entityType = SyncEntityType(rawValue: record.entityType)
            else {
                return nil
            }
            return DeletionTombstone(
                id: id,
                profileID: profileID,
                entityType: entityType,
                entityID: entityID,
                deletedRevision: record.deletedRevision,
                deletedAt: Date(timeIntervalSince1970: record.deletedAt),
                acknowledgedAt: record.acknowledgedAt.map(Date.init(timeIntervalSince1970:)),
                purgeAfter: Date(timeIntervalSince1970: record.purgeAfter)
            )
        }
    }

    func acknowledgeTombstone(id: UUID, at date: Date, purgeAfter: Date) throws {
        try write { database in
            guard var record = try DeletionTombstoneRecord.fetchOne(
                database,
                key: id.uuidString
            ), purgeAfter >= date else {
                throw LocalDatabaseError.constraintViolation
            }
            record.acknowledgedAt = date.timeIntervalSince1970
            record.purgeAfter = purgeAfter.timeIntervalSince1970
            try record.update(database)
        }
    }

    @discardableResult
    func purgeAcknowledgedTombstones(before cutoff: Date) throws -> Int {
        try pool.write { database in
            try DeletionTombstoneRecord
                .filter(Column("acknowledgedAt") != nil)
                .filter(Column("purgeAfter") <= cutoff.timeIntervalSince1970)
                .deleteAll(database)
        }
    }
}
