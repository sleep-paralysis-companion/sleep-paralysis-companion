import Foundation
import Supabase

nonisolated protocol RemoteMutationGateway: Sendable {
    func apply(_ request: RemoteMutationRequest) async throws -> RemoteMutationAcknowledgment
}

nonisolated protocol RemoteMutationRPCExecuting: Sendable {
    func execute(_ parameters: RemoteMutationRPCParameters) async throws -> RemoteMutationRPCResult
}

actor SupabaseRemoteMutationRPCExecutor: RemoteMutationRPCExecuting {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func execute(_ parameters: RemoteMutationRPCParameters) async throws -> RemoteMutationRPCResult {
        let results: [RemoteMutationRPCResult] = try await client
            .rpc("apply_sync_mutation", params: parameters)
            .execute()
            .value
        guard let result = results.first else {
            throw RemoteMutationError.backendUnavailable
        }
        return result
    }
}

actor SupabaseRemoteMutationGateway: RemoteMutationGateway {
    private let executor: any RemoteMutationRPCExecuting
    private let identifier: any IdentifierGenerating

    init(
        client: SupabaseClient,
        identifier: any IdentifierGenerating
    ) {
        executor = SupabaseRemoteMutationRPCExecutor(client: client)
        self.identifier = identifier
    }

    init(
        executor: any RemoteMutationRPCExecuting,
        identifier: any IdentifierGenerating
    ) {
        self.executor = executor
        self.identifier = identifier
    }

    func apply(_ request: RemoteMutationRequest) async throws -> RemoteMutationAcknowledgment {
        guard request.authenticatedUserID == request.payload.ownerUserID else {
            throw RemoteMutationError.authorization
        }
        guard SyncMutationCompatibility.validates(
            operation: request.operation,
            payload: request.payload
        ) else {
            throw RemoteMutationError.validation
        }
        try Task.checkCancellation()

        let receiptID = identifier.next()
        let result = try await applyAtomically(
            request: request,
            receiptID: receiptID
        )
        return RemoteMutationAcknowledgment(
            idempotencyKey: request.operation.idempotencyKey,
            entityID: request.operation.entityID,
            acceptedRevision: result.acceptedRevision,
            serverMutationID: result.serverMutationID,
            acknowledgedAt: result.acknowledgedAt,
            purgeAfter: result.purgeAfter
        )
    }

    private func applyAtomically(
        request: RemoteMutationRequest,
        receiptID: UUID
    ) async throws -> RemoteMutationRPCResult {
        let parameters = RemoteMutationRPCParameters(
            receiptID: receiptID,
            idempotencyKey: request.operation.idempotencyKey,
            entityType: request.operation.entityType.remoteName,
            entityID: request.operation.entityID,
            operation: request.operation.operation.rawValue,
            baseRevision: request.operation.baseRevision,
            entityRevision: request.operation.localRevision,
            payload: request.payload
        )
        return try await executor.execute(parameters)
    }
}
