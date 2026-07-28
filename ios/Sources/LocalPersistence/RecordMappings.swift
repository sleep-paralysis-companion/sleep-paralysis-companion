import Foundation

nonisolated enum RecordMappingError: Error, Equatable, Sendable {
    case invalidStoredValue(table: String, field: String)
}

nonisolated extension LocalProfileRecord {
    init(_ value: LocalProfile) {
        id = value.id.uuidString
        createdAt = value.createdAt.timeIntervalSince1970
        onboardingCompletedAt = value.onboardingCompletedAt?.timeIntervalSince1970
        productNoticeVersion = value.productNoticeVersion
        productNoticeSeenAt = value.productNoticeSeenAt.timeIntervalSince1970
        ownership = value.ownership.rawValue
        accountUserID = value.accountUserID?.uuidString
        accountLinkState = value.accountLinkState.rawValue
    }

    func domainValue() throws -> LocalProfile {
        guard let identifier = UUID(uuidString: id),
              let storedOwnership = ProfileOwnership(rawValue: ownership),
              let linkState = AccountLinkState(rawValue: accountLinkState)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "identity")
        }
        return LocalProfile(
            id: identifier,
            createdAt: Date(timeIntervalSince1970: createdAt),
            onboardingCompletedAt: onboardingCompletedAt.map(Date.init(timeIntervalSince1970:)),
            productNoticeVersion: productNoticeVersion,
            productNoticeSeenAt: Date(timeIntervalSince1970: productNoticeSeenAt),
            ownership: storedOwnership,
            accountUserID: accountUserID.flatMap(UUID.init(uuidString:)),
            accountLinkState: linkState
        )
    }
}

nonisolated extension AppSettingsRecord {
    init(_ value: AppSettings) {
        profileID = value.profileID.uuidString
        preferredGroundingAssetID = value.preferredGroundingAssetID
        preferredModality = value.preferredModality.rawValue
        hapticsEnabled = value.hapticsEnabled
        lastSelectedHistoryPeriod = value.lastSelectedHistoryPeriod.rawValue
        diagnosticsEnabled = value.diagnosticsEnabled
        updatedAt = value.updatedAt.timeIntervalSince1970
        revision = value.revision
    }

    func domainValue() throws -> AppSettings {
        guard let identifier = UUID(uuidString: profileID),
              let modality = GroundingModality(rawValue: preferredModality),
              let period = HistoryPeriod(rawValue: lastSelectedHistoryPeriod)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "enum")
        }
        return AppSettings(
            profileID: identifier,
            preferredGroundingAssetID: preferredGroundingAssetID,
            preferredModality: modality,
            hapticsEnabled: hapticsEnabled,
            lastSelectedHistoryPeriod: period,
            diagnosticsEnabled: diagnosticsEnabled,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            revision: revision
        )
    }
}

nonisolated extension AlarmPreferenceRecord {
    init(_ value: AlarmPreference) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        systemAlarmID = value.systemAlarmID
        localHour = value.localHour
        localMinute = value.localMinute
        weekdaysMask = value.weekdaysMask
        snoozeMinutes = value.snoozeMinutes
        enabledIntent = value.enabledIntent
        systemState = value.systemState.rawValue
        lastScheduleResult = value.lastScheduleResult.rawValue
        createdAt = value.createdAt.timeIntervalSince1970
        updatedAt = value.updatedAt.timeIntervalSince1970
        revision = value.revision
    }

    func domainValue() throws -> AlarmPreference {
        guard let identifier = UUID(uuidString: id),
              let owner = UUID(uuidString: profileID),
              let storedSystemState = AlarmSystemState(rawValue: systemState),
              let scheduleResult = AlarmScheduleResult(rawValue: lastScheduleResult)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "enum")
        }
        return AlarmPreference(
            id: identifier,
            profileID: owner,
            systemAlarmID: systemAlarmID,
            localHour: localHour,
            localMinute: localMinute,
            weekdaysMask: weekdaysMask,
            snoozeMinutes: snoozeMinutes,
            enabledIntent: enabledIntent,
            systemState: storedSystemState,
            lastScheduleResult: scheduleResult,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            revision: revision
        )
    }
}

nonisolated extension SubmittedCheckInRecord {
    init(_ value: SubmittedCheckIn) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        reportedForLocalDate = value.reportedForLocalDate
        reportedTimezoneID = value.reportedTimezoneID
        occurrence = value.occurrence.rawValue
        perceivedIntensity = value.perceivedIntensity?.rawValue
        presentState = value.presentState?.rawValue
        note = value.note
        createdAt = value.createdAt.timeIntervalSince1970
        updatedAt = value.updatedAt.timeIntervalSince1970
        revision = value.revision
        deletedAt = value.deletedAt?.timeIntervalSince1970
    }

    func domainValue() throws -> SubmittedCheckIn {
        guard let identifier = UUID(uuidString: id),
              let owner = UUID(uuidString: profileID),
              let storedOccurrence = EpisodeOccurrence(rawValue: occurrence)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "identity")
        }
        return SubmittedCheckIn(
            id: identifier,
            profileID: owner,
            reportedForLocalDate: reportedForLocalDate,
            reportedTimezoneID: reportedTimezoneID,
            occurrence: storedOccurrence,
            perceivedIntensity: perceivedIntensity.flatMap(PerceivedIntensity.init(rawValue:)),
            presentState: presentState.flatMap(PresentState.init(rawValue:)),
            note: note,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            revision: revision,
            deletedAt: deletedAt.map(Date.init(timeIntervalSince1970:))
        )
    }
}

nonisolated extension SynchronizationOperationRecord {
    init(_ value: SynchronizationOperation) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        entityType = value.entityType.rawValue
        entityID = value.entityID.uuidString
        operation = value.operation.rawValue
        idempotencyKey = value.idempotencyKey.uuidString
        baseRevision = value.baseRevision
        localRevision = value.localRevision
        state = value.state.rawValue
        attemptCount = value.attemptCount
        nextAttemptAt = value.nextAttemptAt?.timeIntervalSince1970
        lastErrorCategory = value.lastErrorCategory?.rawValue
        createdAt = value.createdAt.timeIntervalSince1970
        updatedAt = value.updatedAt.timeIntervalSince1970
    }

    func domainValue() throws -> SynchronizationOperation {
        guard let identifier = UUID(uuidString: id),
              let owner = UUID(uuidString: profileID),
              let storedEntityType = SyncEntityType(rawValue: entityType),
              let storedEntityID = UUID(uuidString: entityID),
              let operationKind = SyncOperationKind(rawValue: operation),
              let key = UUID(uuidString: idempotencyKey),
              let syncState = SynchronizationState(rawValue: state)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "state")
        }
        return SynchronizationOperation(
            id: identifier,
            profileID: owner,
            entityType: storedEntityType,
            entityID: storedEntityID,
            operation: operationKind,
            idempotencyKey: key,
            baseRevision: baseRevision,
            localRevision: localRevision,
            state: syncState,
            attemptCount: attemptCount,
            nextAttemptAt: nextAttemptAt.map(Date.init(timeIntervalSince1970:)),
            lastErrorCategory: lastErrorCategory.flatMap(SyncErrorCategory.init(rawValue:)),
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }
}
