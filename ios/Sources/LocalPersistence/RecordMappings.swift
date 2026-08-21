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
        displayName = value.displayName
        revision = value.revision
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
            accountLinkState: linkState,
            displayName: displayName,
            revision: revision
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
        defaultSleepSupport = value.defaultSleepSupport.rawValue
        defaultPostEpisodeSupport = value.defaultPostEpisodeSupport.rawValue
        updatedAt = value.updatedAt.timeIntervalSince1970
        revision = value.revision
    }

    func domainValue() throws -> AppSettings {
        guard let identifier = UUID(uuidString: profileID),
              let modality = GroundingModality(rawValue: preferredModality),
              let period = HistoryPeriod(rawValue: lastSelectedHistoryPeriod),
              let sleepSupport = DefaultEpisodeSupport(rawValue: defaultSleepSupport),
              let postEpisodeSupport = DefaultEpisodeSupport(rawValue: defaultPostEpisodeSupport)
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
            defaultSleepSupport: sleepSupport,
            defaultPostEpisodeSupport: postEpisodeSupport,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            revision: revision
        )
    }
}

nonisolated extension PartnerContactRecord {
    init(_ value: PartnerContact, profileID: UUID, updatedAt: Date) {
        self.profileID = profileID.uuidString
        name = value.name
        phoneNumber = value.phoneNumber
        self.updatedAt = updatedAt.timeIntervalSince1970
    }

    func domainValue() throws -> PartnerContact {
        guard let value = PartnerContact(name: name, phoneNumber: phoneNumber) else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "contact")
        }
        return value
    }
}

nonisolated extension AlarmPreferenceRecord {
    init(_ value: AlarmPreference) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        systemAlarmID = value.systemAlarmID
        alarmSoundFileName = value.alarmSoundFileName
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
        scheduleName = "Sleep schedule"
        scheduleKind = "sleep"
        sleepHour = value.localHour
        sleepMinute = value.localMinute
        oneTimeLocalDate = nil
        bedtimeReminderLeadMinutes = nil
        prewakeLeadMinutes = nil
        wakeAudioKind = "bundled"
        wakeAudioReference = value.alarmSoundFileName.map { "bundled:\($0)" }
            ?? "bundled:SPCWakeUpGentleLoop.caf"
        displayOrder = 0
    }

    init(_ value: AlarmSchedule) {
        id = value.id.uuidString
        profileID = value.profileID?.uuidString ?? ""
        systemAlarmID = nil
        alarmSoundFileName = value.wakeAudio?.localFileName
        localHour = value.wakeHour
        localMinute = value.wakeMinute
        weekdaysMask = value.weekdaysMask
        snoozeMinutes = nil
        enabledIntent = value.isEnabled
        systemState = AlarmSystemState.notScheduled.rawValue
        lastScheduleResult = AlarmScheduleResult.none.rawValue
        createdAt = value.createdAt.timeIntervalSince1970
        updatedAt = value.updatedAt.timeIntervalSince1970
        scheduleName = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        scheduleKind = value.kind == .sleep ? "sleep" : "wake_only"
        sleepHour = value.bedtimeHour
        sleepMinute = value.bedtimeMinute
        oneTimeLocalDate = value.oneTimeDate?.iso8601String
        bedtimeReminderLeadMinutes = value.bedtimeReminderLeadMinutes
        prewakeLeadMinutes = value.wakeReminderLeadMinutes
        wakeAudioKind = value.wakeAudio.map(AlarmPreferenceRecord.audioKind) ?? "bundled"
        wakeAudioReference = value.wakeAudio.map(AlarmPreferenceRecord.audioReference)
            ?? "bundled:SPCWakeUpGentleLoop.caf"
        displayOrder = value.sortOrder
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
            alarmSoundFileName: alarmSoundFileName,
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

    func scheduleValue() throws -> AlarmSchedule {
        guard let identifier = UUID(uuidString: id),
              let owner = UUID(uuidString: profileID),
              let kind = scheduleKindValue(),
              let audio = audioSelection(),
              let schedule = optionalScheduleDate()
        else {
            throw RecordMappingError.invalidStoredValue(
                table: Self.databaseTableName,
                field: "schedule"
            )
        }

        let value = AlarmSchedule(
            id: identifier,
            profileID: owner,
            name: scheduleName,
            kind: kind,
            bedtimeHour: sleepHour,
            bedtimeMinute: sleepMinute,
            wakeHour: localHour,
            wakeMinute: localMinute,
            weekdaysMask: weekdaysMask,
            oneTimeDate: schedule,
            bedtimeReminderLeadMinutes: bedtimeReminderLeadMinutes,
            wakeReminderLeadMinutes: prewakeLeadMinutes,
            finalWakeAlarmEnabled: true,
            wakeAudio: audio,
            isEnabled: enabledIntent,
            sortOrder: displayOrder,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            revision: revision
        )
        guard value.isValid else {
            throw RecordMappingError.invalidStoredValue(
                table: Self.databaseTableName,
                field: "schedule"
            )
        }
        return value
    }

    private func scheduleKindValue() -> AlarmScheduleKind? {
        switch scheduleKind {
        case "sleep":
            .sleep
        case "wake_only":
            oneTimeLocalDate == nil ? .wakeOnlyRecurring : .wakeOnlyOneTime
        default:
            nil
        }
    }

    private func optionalScheduleDate() -> AlarmLocalDate?? {
        guard let oneTimeLocalDate else { return .some(nil) }
        let parts = oneTimeLocalDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let value = AlarmLocalDate(year: parts[0], month: parts[1], day: parts[2])
        return value.isValid ? .some(value) : nil
    }

    private func audioSelection() -> AlarmAudioSelection? {
        switch wakeAudioKind {
        case "bundled":
            let resource = wakeAudioReference.hasPrefix("bundled:")
                ? String(wakeAudioReference.dropFirst("bundled:".count))
                : wakeAudioReference
            guard !resource.isEmpty else { return nil }
            return AlarmAudioSelection(
                reference: .bundled(resourceName: resource),
                localFileName: alarmSoundFileName
            )
        case "catalog":
            let parts = wakeAudioReference.split(separator: ":")
            guard parts.count == 3,
                  parts[0] == "catalog",
                  let version = Int(parts[2])
            else { return nil }
            return AlarmAudioSelection(
                reference: .catalog(assetID: String(parts[1]), version: version),
                localFileName: alarmSoundFileName
            )
        case "personal":
            let reference = wakeAudioReference.hasPrefix("personal:")
                ? String(wakeAudioReference.dropFirst("personal:".count))
                : ""
            guard let clipID = UUID(uuidString: reference) else { return nil }
            return AlarmAudioSelection(
                reference: .personal(clipID: clipID),
                localFileName: alarmSoundFileName,
                availability: alarmSoundFileName == nil
                    ? .unavailableOnThisDevice
                    : .available
            )
        default:
            return nil
        }
    }

    private static func audioKind(_ selection: AlarmAudioSelection) -> String {
        switch selection.reference {
        case .bundled:
            "bundled"
        case .catalog:
            "catalog"
        case .personal:
            "personal"
        }
    }

    private static func audioReference(_ selection: AlarmAudioSelection) -> String {
        selection.reference.stableIdentifier
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
        spcOutcome = value.spcOutcome?.rawValue
        postEpisodeSupport = value.postEpisodeSupport?.rawValue
        sleepHelpOutcome = value.sleepHelpOutcome?.rawValue
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
            spcOutcome: spcOutcome.flatMap(SPCOutcome.init(rawValue:)),
            postEpisodeSupport: postEpisodeSupport.flatMap(PostEpisodeSupport.init(rawValue:)),
            sleepHelpOutcome: sleepHelpOutcome.flatMap(SleepHelpOutcome.init(rawValue:)),
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

nonisolated extension QuestionnaireDraftRecord {
    init(_ value: QuestionnaireDraft) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        accountUserID = value.accountUserID.uuidString
        episodeFrequency = value.episodeFrequency?.rawValue
        postEpisodeFeeling = value.postEpisodeFeeling?.rawValue
        calmingPersonContext = value.calmingPersonContext?.rawValue
        createdAt = value.createdAt.timeIntervalSince1970
        updatedAt = value.updatedAt.timeIntervalSince1970
    }

    func domainValue() throws -> QuestionnaireDraft {
        guard let id = UUID(uuidString: id),
              let profileID = UUID(uuidString: profileID),
              let accountUserID = UUID(uuidString: accountUserID),
              let episodeFrequency = optionalEnum(episodeFrequency, EpisodeFrequency.init(rawValue:)),
              let postEpisodeFeeling = optionalEnum(postEpisodeFeeling, PostEpisodeFeeling.init(rawValue:)),
              let calmingPersonContext = optionalEnum(
                  calmingPersonContext,
                  CalmingPersonContext.init(rawValue:)
              )
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "enum")
        }
        return QuestionnaireDraft(
            id: id,
            profileID: profileID,
            accountUserID: accountUserID,
            episodeFrequency: episodeFrequency,
            postEpisodeFeeling: postEpisodeFeeling,
            calmingPersonContext: calmingPersonContext,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }
}

private nonisolated func optionalEnum<Value>(
    _ rawValue: String?,
    _ transform: (String) -> Value?
) -> Value?? {
    guard let rawValue else {
        return .some(nil)
    }
    guard let value = transform(rawValue) else {
        return nil
    }
    return .some(value)
}

nonisolated extension PersonaAnswerAggregateRecord {
    init(_ value: PersonaAnswerAggregate) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        accountUserID = value.accountUserID.uuidString
        episodeFrequency = value.episodeFrequency.rawValue
        postEpisodeFeeling = value.postEpisodeFeeling.rawValue
        calmingPersonContext = value.calmingPersonContext.rawValue
        derivedPersona = value.derivedPersona.rawValue
        routingRuleVersion = value.routingRuleVersion
        calculatedAt = value.calculatedAt.timeIntervalSince1970
        createdAt = value.createdAt.timeIntervalSince1970
        updatedAt = value.updatedAt.timeIntervalSince1970
        revision = value.revision
    }

    func domainValue() throws -> PersonaAnswerAggregate {
        guard let id = UUID(uuidString: id),
              let profileID = UUID(uuidString: profileID),
              let accountUserID = UUID(uuidString: accountUserID),
              let episodeFrequency = EpisodeFrequency(rawValue: episodeFrequency),
              let postEpisodeFeeling = PostEpisodeFeeling(rawValue: postEpisodeFeeling),
              let calmingPersonContext = CalmingPersonContext(rawValue: calmingPersonContext),
              let derivedPersona = DerivedPersona(rawValue: derivedPersona)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "enum")
        }
        return PersonaAnswerAggregate(
            id: id,
            profileID: profileID,
            accountUserID: accountUserID,
            episodeFrequency: episodeFrequency,
            postEpisodeFeeling: postEpisodeFeeling,
            calmingPersonContext: calmingPersonContext,
            derivedPersona: derivedPersona,
            routingRuleVersion: routingRuleVersion,
            calculatedAt: Date(timeIntervalSince1970: calculatedAt),
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            revision: revision
        )
    }
}

nonisolated extension PersonalAudioClipMetadataRecord {
    init(_ value: PersonalAudioClipMetadata) {
        id = value.id.uuidString
        profileID = value.profileID.uuidString
        source = value.source.rawValue
        storageFormat = value.storageFormat.rawValue
        byteCount = value.byteCount
        durationMilliseconds = value.durationMilliseconds
        createdOrImportedAt = value.createdOrImportedAt.timeIntervalSince1970
        availability = value.availability.rawValue
        protectionVersion = value.protectionVersion
    }

    func domainValue() throws -> PersonalAudioClipMetadata {
        guard let id = UUID(uuidString: id),
              let profileID = UUID(uuidString: profileID),
              let source = PersonalAudioSource(rawValue: source),
              let storageFormat = PersonalAudioStorageFormat(rawValue: storageFormat),
              let availability = PersonalAudioAvailability(rawValue: availability)
        else {
            throw RecordMappingError.invalidStoredValue(table: Self.databaseTableName, field: "enum")
        }
        return PersonalAudioClipMetadata(
            id: id,
            profileID: profileID,
            source: source,
            storageFormat: storageFormat,
            byteCount: byteCount,
            durationMilliseconds: durationMilliseconds,
            createdOrImportedAt: Date(timeIntervalSince1970: createdOrImportedAt),
            availability: availability,
            protectionVersion: protectionVersion
        )
    }
}
