import Foundation

nonisolated protocol OutboundPayloadProviding: Sendable {
    func payload(
        for operation: SynchronizationOperation,
        authenticatedUserID: UUID
    ) async throws -> RemoteMutationPayload
}

nonisolated struct SynchronizationBackoff: Sendable {
    let base: TimeInterval
    let cap: TimeInterval
    let jitterFraction: Double

    func delay(attempt: Int, randomUnit: Double) -> TimeInterval {
        let exponent = max(0, min(attempt - 1, 20))
        let unjittered = min(cap, base * pow(2, Double(exponent)))
        let boundedRandom = min(1, max(0, randomUnit))
        let jitter = unjittered * jitterFraction * boundedRandom
        return min(cap, unjittered + jitter)
    }

    static let phase1B = SynchronizationBackoff(
        base: 2,
        cap: 15 * 60,
        jitterFraction: 0.25
    )
}

actor SynchronizationEngine {
    private let database: LocalDatabase
    private let payloadProvider: any OutboundPayloadProviding
    private let remote: any RemoteMutationGateway
    private let clock: any Phase1BClock
    private let random: any UnitIntervalRandom
    private let backoff: SynchronizationBackoff

    init(
        database: LocalDatabase,
        payloadProvider: any OutboundPayloadProviding,
        remote: any RemoteMutationGateway,
        clock: any Phase1BClock,
        random: any UnitIntervalRandom,
        backoff: SynchronizationBackoff = .phase1B
    ) {
        self.database = database
        self.payloadProvider = payloadProvider
        self.remote = remote
        self.clock = clock
        self.random = random
        self.backoff = backoff
    }

    @discardableResult
    func synchronizeNext(profileID: UUID, authenticatedUserID: UUID) async throws -> Bool {
        let startedAt = clock.now()
        guard var operation = try await database.claimNextOperation(profileID: profileID, now: startedAt) else {
            return false
        }

        do {
            try Task.checkCancellation()
            let payload = try await payloadProvider.payload(
                for: operation,
                authenticatedUserID: authenticatedUserID
            )
            let acknowledgment = try await remote.apply(
                RemoteMutationRequest(
                    operation: operation,
                    authenticatedUserID: authenticatedUserID,
                    payload: payload
                )
            )
            try Task.checkCancellation()
            guard acknowledgment.idempotencyKey == operation.idempotencyKey,
                  acknowledgment.entityID == operation.entityID,
                  acknowledgment.acceptedRevision == operation.localRevision
            else {
                throw RemoteMutationError.staleResponse
            }
            if operation.entityType == .tombstone,
               acknowledgment.acknowledgedAt == nil || acknowledgment.purgeAfter == nil
            {
                throw RemoteMutationError.staleResponse
            }
            operation.state = operation.operation == .delete ? .deleted : .synced
            operation.lastErrorCategory = nil
            operation.nextAttemptAt = nil
            operation.updatedAt = clock.now()
            try await database.acknowledgeRemoteMutation(
                operation: operation,
                acknowledgment: acknowledgment
            )
            return true
        } catch is CancellationError {
            operation.state = .failedRecoverable
            operation.lastErrorCategory = .cancelled
            operation.nextAttemptAt = clock.now()
            operation.updatedAt = clock.now()
            try await database.saveOperation(operation)
            throw CancellationError()
        } catch let error as RemoteMutationError {
            apply(error: error, to: &operation)
            try await database.saveOperation(operation)
            return true
        } catch {
            operation.state = .failedRecoverable
            operation.lastErrorCategory = .network
            operation.nextAttemptAt = retryDate(for: operation)
            operation.updatedAt = clock.now()
            try await database.saveOperation(operation)
            return true
        }
    }

    private func apply(error: RemoteMutationError, to operation: inout SynchronizationOperation) {
        operation.updatedAt = clock.now()
        switch error {
        case .authentication:
            operation.state = .authRequired
            operation.lastErrorCategory = .authentication
            operation.nextAttemptAt = nil
        case .authorization:
            operation.state = .conflicted
            operation.lastErrorCategory = .authorization
            operation.nextAttemptAt = nil
        case .validation:
            operation.state = .conflicted
            operation.lastErrorCategory = .validation
            operation.nextAttemptAt = nil
        case .conflict, .staleResponse:
            operation.state = .conflicted
            operation.lastErrorCategory = .conflict
            operation.nextAttemptAt = nil
        case .network:
            operation.state = .failedRecoverable
            operation.lastErrorCategory = .network
            operation.nextAttemptAt = retryDate(for: operation)
        case .backendUnavailable:
            operation.state = .failedRecoverable
            operation.lastErrorCategory = .backendUnavailable
            operation.nextAttemptAt = retryDate(for: operation)
        }
    }

    private func retryDate(for operation: SynchronizationOperation) -> Date {
        let delay = backoff.delay(attempt: operation.attemptCount, randomUnit: random.next())
        return clock.now().addingTimeInterval(delay)
    }
}

nonisolated enum ConflictChoice: String, Codable, CaseIterable, Sendable {
    case useDevice
    case useAccount
    case keepLocalRevision
    case keepRemoteRevision
    case keepDelete
}

nonisolated enum ConflictResolution: Equatable, Sendable {
    case deduplicated
    case union
    case requiresChoice(Set<ConflictChoice>)
    case delete
}

nonisolated struct EntityConflictResolver: Sendable {
    func resolve(
        entityType: SyncEntityType,
        sameStableID: Bool,
        sameContent: Bool,
        deleteBaseIncludesEdit: Bool
    ) -> ConflictResolution {
        switch entityType {
        case .profile:
            return .requiresChoice([.useAccount])
        case .settings, .alarm:
            return .requiresChoice([.useDevice, .useAccount])
        case .checkIn:
            if !sameStableID {
                return .union
            }
            if sameContent {
                return .deduplicated
            }
            return .requiresChoice([.keepLocalRevision, .keepRemoteRevision])
        case .tombstone:
            if deleteBaseIncludesEdit {
                return .delete
            }
            return .requiresChoice([.keepRemoteRevision, .keepDelete])
        }
    }
}
