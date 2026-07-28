import Foundation

nonisolated struct RemoteProfileDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let profileCreatedAt: Date
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case profileCreatedAt = "profile_created_at"
        case revision
    }
}

nonisolated struct RemoteSettingsDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let preferredGroundingAssetID: String?
    let preferredModality: String
    let hapticsEnabled: Bool
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case preferredGroundingAssetID = "preferred_grounding_asset_id"
        case preferredModality = "preferred_modality"
        case hapticsEnabled = "haptics_enabled"
        case revision
    }
}

nonisolated struct RemoteAlarmPreferenceDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let localHour: Int
    let localMinute: Int
    let weekdaysMask: Int
    let snoozeMinutes: Int?
    let enabledIntent: Bool
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case localHour = "local_hour"
        case localMinute = "local_minute"
        case weekdaysMask = "weekdays_mask"
        case snoozeMinutes = "snooze_minutes"
        case enabledIntent = "enabled_intent"
        case revision
    }
}

nonisolated struct RemoteCheckInDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let reportedForLocalDate: String
    let reportedTimezoneID: String
    let occurrence: String
    let perceivedIntensity: String?
    let presentState: String?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    let revision: Int64
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case reportedForLocalDate = "reported_for_local_date"
        case reportedTimezoneID = "reported_timezone_id"
        case occurrence
        case perceivedIntensity = "perceived_intensity"
        case presentState = "present_state"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revision
        case deletedAt = "deleted_at"
    }
}

nonisolated struct RemoteTombstoneDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let entityType: String
    let entityID: UUID
    let deletedRevision: Int64
    let deletedAt: Date
    let acknowledgedAt: Date?
    let purgeAfter: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case entityType = "entity_type"
        case entityID = "entity_id"
        case deletedRevision = "deleted_revision"
        case deletedAt = "deleted_at"
        case acknowledgedAt = "acknowledged_at"
        case purgeAfter = "purge_after"
    }
}

nonisolated struct RemoteMutationReceiptDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let idempotencyKey: UUID
    let entityType: String
    let entityID: UUID
    let operation: String
    let entityRevision: Int64
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case idempotencyKey = "idempotency_key"
        case entityType = "entity_type"
        case entityID = "entity_id"
        case operation
        case entityRevision = "entity_revision"
        case expiresAt = "expires_at"
    }
}

nonisolated struct RemoteMutationRPCParameters<Payload: Encodable & Sendable>: Encodable, Sendable {
    let receiptID: UUID
    let idempotencyKey: UUID
    let entityType: String
    let entityID: UUID
    let operation: String
    let entityRevision: Int64
    let payload: Payload

    enum CodingKeys: String, CodingKey {
        case receiptID = "p_receipt_id"
        case idempotencyKey = "p_idempotency_key"
        case entityType = "p_entity_type"
        case entityID = "p_entity_id"
        case operation = "p_operation"
        case entityRevision = "p_entity_revision"
        case payload = "p_payload"
    }
}

nonisolated struct RemoteMutationRPCResult: Decodable, Sendable {
    let serverMutationID: UUID
    let acceptedRevision: Int64

    enum CodingKeys: String, CodingKey {
        case serverMutationID = "server_mutation_id"
        case acceptedRevision = "accepted_revision"
    }
}

nonisolated enum RemoteMutationPayload: Sendable {
    case profile(RemoteProfileDTO)
    case settings(RemoteSettingsDTO)
    case alarm(RemoteAlarmPreferenceDTO)
    case checkIn(RemoteCheckInDTO)
    case tombstone(RemoteTombstoneDTO)
}

nonisolated struct RemoteMutationRequest: Sendable {
    let operation: SynchronizationOperation
    let authenticatedUserID: UUID
    let payload: RemoteMutationPayload
}

nonisolated struct RemoteMutationAcknowledgment: Equatable, Sendable {
    let idempotencyKey: UUID
    let entityID: UUID
    let acceptedRevision: Int64
    let serverMutationID: UUID
}

nonisolated enum RemoteMutationError: Error, Equatable, Sendable {
    case network
    case backendUnavailable
    case authentication
    case authorization
    case validation
    case conflict(remoteRevision: Int64)
    case staleResponse
}
