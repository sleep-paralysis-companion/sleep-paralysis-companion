import Foundation

nonisolated enum SyncMutationCompatibility {
    static func allows(operation: SyncOperationKind, entityType: SyncEntityType) -> Bool {
        switch operation {
        case .upsert:
            entityType != .tombstone
        case .convert:
            entityType != .tombstone && entityType != .persona
        case .delete:
            entityType == .tombstone
        }
    }

    static func validates(
        operation: SynchronizationOperation,
        payload: RemoteMutationPayload
    ) -> Bool {
        allows(operation: operation.operation, entityType: operation.entityType)
            && payload.entityType == operation.entityType
            && payload.entityID == operation.entityID
            && payload.revision == operation.localRevision
    }
}

nonisolated struct LocalDatabaseOutboundPayloadProvider: OutboundPayloadProviding {
    private let database: LocalDatabase

    init(database: LocalDatabase) {
        self.database = database
    }

    func payload(
        for operation: SynchronizationOperation,
        authenticatedUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard SyncMutationCompatibility.allows(
            operation: operation.operation,
            entityType: operation.entityType
        ) else {
            throw RemoteMutationError.validation
        }
        guard let profile = try await database.profile(id: operation.profileID) else {
            throw RemoteMutationError.validation
        }
        try await validateOwner(
            profile: profile,
            operation: operation,
            authenticatedUserID: authenticatedUserID
        )

        let payload: RemoteMutationPayload = switch operation.entityType {
        case .profile:
            try profilePayload(
                profile,
                operation: operation,
                ownerUserID: authenticatedUserID
            )
        case .settings:
            try await settingsPayload(
                operation: operation,
                ownerUserID: authenticatedUserID
            )
        case .alarm:
            try await alarmPayload(
                operation: operation,
                ownerUserID: authenticatedUserID
            )
        case .checkIn:
            try await checkInPayload(
                operation: operation,
                ownerUserID: authenticatedUserID
            )
        case .persona:
            try await personaPayload(
                operation: operation,
                ownerUserID: authenticatedUserID
            )
        case .tombstone:
            try await tombstonePayload(
                operation: operation,
                ownerUserID: authenticatedUserID
            )
        }

        guard SyncMutationCompatibility.validates(operation: operation, payload: payload),
              payload.ownerUserID == authenticatedUserID
        else {
            throw RemoteMutationError.validation
        }
        return payload
    }

    private func validateOwner(
        profile: LocalProfile,
        operation: SynchronizationOperation,
        authenticatedUserID: UUID
    ) async throws {
        if profile.accountUserID == authenticatedUserID {
            return
        }
        guard operation.operation == .convert,
              profile.ownership == .guestLocal,
              profile.accountUserID == nil,
              let checkpoint = try await database.conversionCheckpoint(profileID: profile.id),
              checkpoint.expectedUserID == authenticatedUserID
        else {
            throw RemoteMutationError.authorization
        }
    }

    private func profilePayload(
        _ profile: LocalProfile,
        operation: SynchronizationOperation,
        ownerUserID: UUID
    ) throws -> RemoteMutationPayload {
        guard profile.id == operation.entityID else {
            throw RemoteMutationError.validation
        }
        return .profile(
            RemoteProfileDTO(
                id: profile.id,
                ownerUserID: ownerUserID,
                profileCreatedAt: profile.createdAt,
                displayName: profile.displayName,
                revision: operation.localRevision
            )
        )
    }

    private func settingsPayload(
        operation: SynchronizationOperation,
        ownerUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard operation.entityID == operation.profileID,
              let settings = try await database.settings(profileID: operation.profileID),
              settings.profileID == operation.profileID,
              settings.revision == operation.localRevision
        else {
            throw RemoteMutationError.validation
        }
        return .settings(
            RemoteSettingsDTO(
                id: settings.profileID,
                ownerUserID: ownerUserID,
                preferredGroundingAssetID: settings.preferredGroundingAssetID,
                preferredModality: settings.preferredModality.rawValue,
                hapticsEnabled: settings.hapticsEnabled,
                defaultSleepSupport: settings.defaultSleepSupport.rawValue,
                defaultPostEpisodeSupport: settings.defaultPostEpisodeSupport.rawValue,
                revision: settings.revision
            )
        )
    }

    private func alarmPayload(
        operation: SynchronizationOperation,
        ownerUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard let alarm = try await database.alarm(
            id: operation.entityID,
            profileID: operation.profileID
        ) else {
            throw RemoteMutationError.validation
        }
        guard alarm.profileID == operation.profileID,
              alarm.revision == operation.localRevision
        else {
            throw RemoteMutationError.validation
        }
        guard let schedule = try await database.alarmSchedule(
            id: operation.entityID,
            profileID: operation.profileID
        ), let audio = schedule.wakeAudio else {
            throw RemoteMutationError.validation
        }
        guard schedule.revision == operation.localRevision else {
            throw RemoteMutationError.validation
        }
        return .alarm(
            RemoteAlarmPreferenceDTO(
                id: schedule.id,
                ownerUserID: ownerUserID,
                localHour: schedule.wakeHour,
                localMinute: schedule.wakeMinute,
                weekdaysMask: schedule.weekdaysMask,
                snoozeMinutes: alarm.snoozeMinutes,
                enabledIntent: schedule.isEnabled,
                revision: schedule.revision,
                scheduleName: schedule.name,
                scheduleKind: schedule.kind == .sleep ? "sleep" : "wake_only",
                sleepHour: schedule.bedtimeHour,
                sleepMinute: schedule.bedtimeMinute,
                oneTimeLocalDate: schedule.oneTimeDate?.iso8601String,
                bedtimeReminderLeadMinutes: schedule.bedtimeReminderLeadMinutes,
                prewakeLeadMinutes: schedule.wakeReminderLeadMinutes,
                wakeAudioKind: try audioKind(audio),
                wakeAudioReference: audio.reference.stableIdentifier,
                displayOrder: schedule.sortOrder
            )
        )
    }

    private func audioKind(_ selection: AlarmAudioSelection) throws -> String {
        switch selection.reference {
        case .bundled:
            "bundled"
        case .catalog:
            "catalog"
        case .personal:
            throw RemoteMutationError.validation
        }
    }

    private func checkInPayload(
        operation: SynchronizationOperation,
        ownerUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard let checkIn = try await database.checkIn(
            id: operation.entityID,
            profileID: operation.profileID
        ) else {
            throw RemoteMutationError.validation
        }
        guard checkIn.profileID == operation.profileID,
              checkIn.revision == operation.localRevision,
              checkIn.deletedAt == nil
        else {
            throw RemoteMutationError.validation
        }
        return .checkIn(
            RemoteCheckInDTO(
                id: checkIn.id,
                ownerUserID: ownerUserID,
                reportedForLocalDate: checkIn.reportedForLocalDate,
                reportedTimezoneID: checkIn.reportedTimezoneID,
                occurrence: checkIn.occurrence.rawValue,
                perceivedIntensity: checkIn.perceivedIntensity?.rawValue,
                presentState: checkIn.presentState?.rawValue,
                note: checkIn.note,
                createdAt: checkIn.createdAt,
                updatedAt: checkIn.updatedAt,
                revision: checkIn.revision,
                deletedAt: nil
            )
        )
    }

    private func tombstonePayload(
        operation: SynchronizationOperation,
        ownerUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard let tombstone = try await database.tombstone(
            id: operation.entityID,
            profileID: operation.profileID
        ) else {
            throw RemoteMutationError.validation
        }
        guard tombstone.profileID == operation.profileID,
              tombstone.id == operation.entityID,
              tombstone.deletedRevision == operation.localRevision
        else {
            throw RemoteMutationError.validation
        }
        return .tombstone(
            RemoteTombstoneDTO(
                id: tombstone.id,
                ownerUserID: ownerUserID,
                entityType: tombstone.entityType.remoteName,
                entityID: tombstone.entityID,
                deletedRevision: tombstone.deletedRevision,
                deletedAt: tombstone.deletedAt
            )
        )
    }

    private func personaPayload(
        operation: SynchronizationOperation,
        ownerUserID: UUID
    ) async throws -> RemoteMutationPayload {
        guard operation.operation == .upsert,
              operation.entityID == operation.profileID,
              let aggregate = try await database.personaAnswerAggregate(
                  profileID: operation.profileID,
                  authenticatedUserID: ownerUserID
              ),
              aggregate.id == operation.entityID,
              aggregate.accountUserID == ownerUserID,
              aggregate.revision == operation.localRevision,
              aggregate.derivedPersona == PersonaRouting.derive(
                  episodeFrequency: aggregate.episodeFrequency,
                  postEpisodeFeeling: aggregate.postEpisodeFeeling,
                  calmingPersonContext: aggregate.calmingPersonContext
              )
        else {
            throw RemoteMutationError.validation
        }
        return .persona(
            RemotePersonaAnswerAggregateDTO(
                id: aggregate.id,
                ownerUserID: ownerUserID,
                episodeFrequency: aggregate.episodeFrequency.rawValue,
                postEpisodeFeeling: aggregate.postEpisodeFeeling.rawValue,
                calmingPersonContext: aggregate.calmingPersonContext.rawValue,
                routingRuleVersion: aggregate.routingRuleVersion,
                calculatedAt: aggregate.calculatedAt,
                updatedAt: aggregate.updatedAt,
                revision: aggregate.revision
            )
        )
    }
}
