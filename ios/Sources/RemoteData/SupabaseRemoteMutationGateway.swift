import Foundation
import Supabase

nonisolated protocol RemoteMutationGateway: Sendable {
    func apply(_ request: RemoteMutationRequest) async throws -> RemoteMutationAcknowledgment
}

actor SupabaseRemoteMutationGateway: RemoteMutationGateway {
    private let client: SupabaseClient
    private let identifier: any IdentifierGenerating

    init(
        client: SupabaseClient,
        identifier: any IdentifierGenerating
    ) {
        self.client = client
        self.identifier = identifier
    }

    func apply(_ request: RemoteMutationRequest) async throws -> RemoteMutationAcknowledgment {
        guard request.authenticatedUserID == ownerID(for: request.payload) else {
            throw RemoteMutationError.authorization
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
            serverMutationID: result.serverMutationID
        )
    }

    private func applyAtomically(
        request: RemoteMutationRequest,
        receiptID: UUID
    ) async throws -> RemoteMutationRPCResult {
        switch request.payload {
        case let .profile(value):
            try await execute(request: request, receiptID: receiptID, payload: value)
        case let .settings(value):
            try await execute(request: request, receiptID: receiptID, payload: value)
        case let .alarm(value):
            try await execute(request: request, receiptID: receiptID, payload: value)
        case let .checkIn(value):
            try await execute(request: request, receiptID: receiptID, payload: value)
        case let .tombstone(value):
            try await execute(request: request, receiptID: receiptID, payload: value)
        }
    }

    private func execute(
        request: RemoteMutationRequest,
        receiptID: UUID,
        payload: some Encodable & Sendable
    ) async throws -> RemoteMutationRPCResult {
        let parameters = RemoteMutationRPCParameters(
            receiptID: receiptID,
            idempotencyKey: request.operation.idempotencyKey,
            entityType: request.operation.entityType.rawValue,
            entityID: request.operation.entityID,
            operation: request.operation.operation.rawValue,
            entityRevision: request.operation.localRevision,
            payload: payload
        )
        let results: [RemoteMutationRPCResult] = try await client
            .rpc("apply_sync_mutation", params: parameters)
            .execute()
            .value
        guard let result = results.first else {
            throw RemoteMutationError.backendUnavailable
        }
        return result
    }

    private func ownerID(for payload: RemoteMutationPayload) -> UUID {
        switch payload {
        case let .profile(value):
            value.ownerUserID
        case let .settings(value):
            value.ownerUserID
        case let .alarm(value):
            value.ownerUserID
        case let .checkIn(value):
            value.ownerUserID
        case let .tombstone(value):
            value.ownerUserID
        }
    }
}
