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

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case entityType = "entity_type"
        case entityID = "entity_id"
        case deletedRevision = "deleted_revision"
        case deletedAt = "deleted_at"
    }
}

nonisolated struct RemotePersonaAnswerAggregateDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let episodeFrequency: String
    let postEpisodeFeeling: String
    let calmingPersonContext: String
    let routingRuleVersion: String
    let calculatedAt: Date
    let updatedAt: Date
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case episodeFrequency = "episode_frequency"
        case postEpisodeFeeling = "post_episode_feeling"
        case calmingPersonContext = "calming_person_context"
        case routingRuleVersion = "routing_rule_version"
        case calculatedAt = "calculated_at"
        case updatedAt = "updated_at"
        case revision
    }
}

nonisolated struct RemoteMutationReceiptDTO: Codable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let idempotencyKey: UUID
    let entityType: String
    let entityID: UUID
    let operation: String
    let baseRevision: Int64
    let entityRevision: Int64
    let payloadHash: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case idempotencyKey = "idempotency_key"
        case entityType = "entity_type"
        case entityID = "entity_id"
        case operation
        case baseRevision = "base_revision"
        case entityRevision = "entity_revision"
        case payloadHash = "payload_hash"
        case expiresAt = "expires_at"
    }
}

nonisolated struct RemoteMutationRPCParameters: Encodable, Sendable {
    let receiptID: UUID
    let idempotencyKey: UUID
    let entityType: String
    let entityID: UUID
    let operation: String
    let baseRevision: Int64
    let entityRevision: Int64
    let payload: RemoteMutationPayload

    enum CodingKeys: String, CodingKey {
        case receiptID = "p_receipt_id"
        case idempotencyKey = "p_idempotency_key"
        case entityType = "p_entity_type"
        case entityID = "p_entity_id"
        case operation = "p_operation"
        case baseRevision = "p_base_revision"
        case entityRevision = "p_entity_revision"
        case payload = "p_payload"
    }
}

nonisolated struct RemoteMutationRPCResult: Decodable, Sendable {
    let serverMutationID: UUID
    let acceptedRevision: Int64
    let acknowledgedAt: Date?
    let purgeAfter: Date?

    enum CodingKeys: String, CodingKey {
        case serverMutationID = "server_mutation_id"
        case acceptedRevision = "accepted_revision"
        case acknowledgedAt = "acknowledged_at"
        case purgeAfter = "purge_after"
    }
}

nonisolated enum RemoteMutationPayload: Encodable, Sendable {
    case profile(RemoteProfileDTO)
    case settings(RemoteSettingsDTO)
    case alarm(RemoteAlarmPreferenceDTO)
    case checkIn(RemoteCheckInDTO)
    case persona(RemotePersonaAnswerAggregateDTO)
    case tombstone(RemoteTombstoneDTO)

    var entityType: SyncEntityType {
        switch self {
        case .profile:
            .profile
        case .settings:
            .settings
        case .alarm:
            .alarm
        case .checkIn:
            .checkIn
        case .persona:
            .persona
        case .tombstone:
            .tombstone
        }
    }

    var entityID: UUID {
        switch self {
        case let .profile(value):
            value.id
        case let .settings(value):
            value.id
        case let .alarm(value):
            value.id
        case let .checkIn(value):
            value.id
        case let .persona(value):
            value.id
        case let .tombstone(value):
            value.id
        }
    }

    var ownerUserID: UUID {
        switch self {
        case let .profile(value):
            value.ownerUserID
        case let .settings(value):
            value.ownerUserID
        case let .alarm(value):
            value.ownerUserID
        case let .checkIn(value):
            value.ownerUserID
        case let .persona(value):
            value.ownerUserID
        case let .tombstone(value):
            value.ownerUserID
        }
    }

    var revision: Int64 {
        switch self {
        case let .profile(value):
            value.revision
        case let .settings(value):
            value.revision
        case let .alarm(value):
            value.revision
        case let .checkIn(value):
            value.revision
        case let .persona(value):
            value.revision
        case let .tombstone(value):
            value.deletedRevision
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .profile(value):
            try value.encode(to: encoder)
        case let .settings(value):
            try value.encode(to: encoder)
        case let .alarm(value):
            try value.encode(to: encoder)
        case let .checkIn(value):
            try value.encode(to: encoder)
        case let .persona(value):
            try value.encode(to: encoder)
        case let .tombstone(value):
            try value.encode(to: encoder)
        }
    }
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
    let acknowledgedAt: Date?
    let purgeAfter: Date?
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
