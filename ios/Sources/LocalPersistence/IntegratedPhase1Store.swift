import Foundation

nonisolated struct Phase1ResumeSnapshot: Sendable {
    let profile: LocalProfile
    let questionnaireDraft: QuestionnaireDraft?
    let persona: PersonaAnswerAggregate?
    let clips: [PersonalAudioClipMetadata]
    let audioDefault: LocalRecoveryAudioDefault?
    let schedule: SleepSchedule
    let checkIns: [SubmittedCheckIn]
    let settings: AppSettings
}

actor IntegratedPhase1Store {
    private let location: LocalStoreLocation
    private let protection: any ProtectedFileApplying
    private let preferences: AccountBoundPreferencesStore
    private let remote: (any RemoteMutationGateway)?
    private var database: LocalDatabase?

    init(
        location: LocalStoreLocation,
        protection: any ProtectedFileApplying = SystemProtectedFileApplicator(),
        preferences: AccountBoundPreferencesStore = AccountBoundPreferencesStore(),
        remote: (any RemoteMutationGateway)? = nil
    ) {
        self.location = location
        self.protection = protection
        self.preferences = preferences
        self.remote = remote
    }

    func resume(session: AuthenticationSessionMaterial) async throws -> Phase1ResumeSnapshot {
        let database = try databaseInstance()
        let profile = try await database.activateAuthenticatedProfile(
            userID: session.userID,
            provider: session.provider,
            sessionExpiresAt: session.expiresAt,
            now: Date()
        )
        try await enqueueInitialRemoteState(database: database, profile: profile)
        await synchronizePending(profileID: profile.id, userID: session.userID)
        return try await snapshot(profile: profile, userID: session.userID)
    }

    func saveDraft(_ draft: QuestionnaireDraft) async throws {
        try await databaseInstance().saveQuestionnaireDraft(draft)
    }

    func completeQuestionnaire(
        profileID: UUID,
        userID: UUID
    ) async throws -> PersonaAnswerAggregate {
        let aggregate = try await databaseInstance().completeQuestionnaireDraft(
            profileID: profileID,
            authenticatedUserID: userID,
            calculatedAt: Date()
        )
        await synchronizePending(profileID: profileID, userID: userID)
        return aggregate
    }

    func replacePersona(_ aggregate: PersonaAnswerAggregate) async throws {
        try await databaseInstance().replacePersonaAnswerAggregate(aggregate)
        await synchronizePending(profileID: aggregate.profileID, userID: aggregate.accountUserID)
    }

    func saveClip(_ metadata: PersonalAudioClipMetadata, userID: UUID) async throws {
        try await databaseInstance().savePersonalAudioClipMetadata(
            metadata,
            authenticatedUserID: userID
        )
    }

    func deleteClip(
        id: UUID,
        profileID: UUID,
        userID: UUID
    ) async throws {
        try await databaseInstance().deletePersonalAudioClipMetadata(
            id: id,
            profileID: profileID,
            authenticatedUserID: userID
        )
    }

    func setAudioDefault(
        _ value: LocalRecoveryAudioDefault,
        profileID: UUID,
        userID: UUID
    ) async throws {
        try await databaseInstance().setLocalRecoveryAudioDefault(
            value,
            profileID: profileID,
            authenticatedUserID: userID,
            updatedAt: Date()
        )
    }

    func saveSchedule(
        _ schedule: SleepSchedule,
        profileID: UUID,
        userID: UUID
    ) async throws -> AlarmPreference {
        guard schedule.isValid else { throw Phase1ActionError.invalidSchedule }
        try await preferences.write(schedule, userID: userID)
        let database = try databaseInstance()
        let existing = try await database.alarms(profileID: profileID).first
        let now = Date()
        let alarmID = existing?.id ?? UUID()
        let wakePlan = WakeAlarmPlanner.plan(for: schedule)
        let preference = AlarmPreference(
            id: alarmID,
            profileID: profileID,
            systemAlarmID: nil,
            localHour: wakePlan?.hour ?? schedule.wakeHour,
            localMinute: wakePlan?.minute ?? schedule.wakeMinute,
            weekdaysMask: wakePlan.map { weekdaysMask(for: $0) } ?? schedule.weekdaysMask,
            snoozeMinutes: nil,
            enabledIntent: schedule.wakeAlarmIsRequested,
            systemState: .notScheduled,
            lastScheduleResult: .none,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            revision: (existing?.revision ?? 0) + 1
        )
        try await database.saveAlarm(preference)
        try await enqueueLatestUpsert(
            database: database,
            profileID: profileID,
            entityType: .alarm,
            entityID: alarmID,
            revision: (existing?.revision ?? 0) + 1
        )
        try await database.markIntegratedOnboardingComplete(
            profileID: profileID,
            userID: userID,
            completedAt: now
        )
        await synchronizePending(profileID: profileID, userID: userID)
        return preference
    }

    func saveWakeAlarmPreference(
        _ preference: AlarmPreference,
        profileID: UUID,
        userID: UUID
    ) async throws {
        guard preference.profileID == profileID else { throw Phase1ActionError.accountMismatch }
        let database = try databaseInstance()
        try await database.saveAlarm(preference)
        try await enqueueLatestUpsert(
            database: database,
            profileID: profileID,
            entityType: .alarm,
            entityID: preference.id,
            revision: preference.revision
        )
        await synchronizePending(profileID: profileID, userID: userID)
    }

    func saveCheckIn(_ value: SubmittedCheckIn, userID: UUID) async throws {
        let database = try databaseInstance()
        try await database.submitCheckIn(value, draftID: nil)
        try await enqueueLatestUpsert(
            database: database,
            profileID: value.profileID,
            entityType: .checkIn,
            entityID: value.id,
            revision: value.revision
        )
        await synchronizePending(profileID: value.profileID, userID: userID)
    }

    func saveProfile(_ profile: LocalProfile, userID: UUID) async throws {
        guard profile.accountUserID == userID else { throw AuthenticationError.wrongAccount }
        let database = try databaseInstance()
        try await database.saveProfile(profile)
        try await enqueueLatestUpsert(
            database: database,
            profileID: profile.id,
            entityType: .profile,
            entityID: profile.id,
            revision: profile.revision
        )
        await synchronizePending(profileID: profile.id, userID: userID)
    }

    func saveSettings(_ settings: AppSettings, userID: UUID) async throws {
        let database = try databaseInstance()
        try await database.saveSettings(settings)
        try await enqueueLatestUpsert(
            database: database,
            profileID: settings.profileID,
            entityType: .settings,
            entityID: settings.profileID,
            revision: settings.revision
        )
        await synchronizePending(profileID: settings.profileID, userID: userID)
    }

    func deleteCheckIn(_ value: SubmittedCheckIn, userID: UUID) async throws {
        try await databaseInstance().deleteCheckIn(
            DeleteCheckInRequest(
                id: value.id,
                profileID: value.profileID,
                date: Date(),
                tombstoneID: UUID(),
                operationID: UUID(),
                idempotencyKey: UUID()
            )
        )
        await synchronizePending(profileID: value.profileID, userID: userID)
    }

    func export(
        profileID: UUID,
        userID: UUID,
        appVersion: String,
        directory: URL
    ) async throws -> ExportArtifact {
        let snapshot = try await databaseInstance().exportSnapshot(
            appVersion: appVersion,
            policyVersions: ["persona_routing": PersonaRouting.initialRuleVersion],
            profileID: profileID,
            authenticatedUserID: userID,
            scope: .lastSyncedLocalSnapshot
        )
        let service = LocalExportService(
            clock: SystemPhase1BClock(),
            identifier: SystemIdentifierGenerator(),
            protection: SystemProtectedFileApplicator()
        )
        let artifact = try service.create(snapshot: snapshot, profileID: profileID, in: directory)
        try await databaseInstance().saveExportMetadata(artifact.metadata)
        return artifact
    }

    func cleanupStructuredExports(
        in directory: URL,
        now: Date = Date(),
        maximumEntries: Int = 64
    ) throws {
        try exportService().cleanupExpired(
            in: directory,
            now: now,
            maximumEntries: maximumEntries
        )
    }

    func removeStructuredExport(at url: URL) throws {
        try exportService().remove(url)
    }

    func deleteAllLocalData(userID: UUID) async throws {
        try await preferences.delete(userID: userID)
        try await databaseInstance().deleteAllLocalData()
    }

    private func snapshot(
        profile: LocalProfile,
        userID: UUID
    ) async throws -> Phase1ResumeSnapshot {
        let database = try databaseInstance()
        let questionnaireDraft = try await database.questionnaireDraft(
            profileID: profile.id,
            authenticatedUserID: userID
        )
        let persona = try await database.personaAnswerAggregate(
            profileID: profile.id,
            authenticatedUserID: userID
        )
        let clips = try await database.personalAudioClipMetadata(
            profileID: profile.id,
            authenticatedUserID: userID
        )
        let audioDefault = try await database.localRecoveryAudioDefault(
            profileID: profile.id,
            authenticatedUserID: userID
        )
        let schedule = try await preferences.read(userID: userID) ?? .defaultValue
        let checkIns = try await database.checkIns(profileID: profile.id)
        guard let settings = try await database.settings(profileID: profile.id) else {
            throw LocalDatabaseError.corruptOrUnreadable
        }
        return Phase1ResumeSnapshot(
            profile: profile,
            questionnaireDraft: questionnaireDraft,
            persona: persona,
            clips: clips,
            audioDefault: audioDefault,
            schedule: schedule,
            checkIns: checkIns,
            settings: settings
        )
    }

    private func enqueueInitialRemoteState(
        database: LocalDatabase,
        profile: LocalProfile
    ) async throws {
        let now = Date()
        for operation in [
            makeUpsert(
                profileID: profile.id,
                entityType: .profile,
                entityID: profile.id,
                revision: 1,
                at: now
            ),
            makeUpsert(
                profileID: profile.id,
                entityType: .settings,
                entityID: profile.id,
                revision: 1,
                at: now
            ),
        ] {
            try await database.enqueueInitialUpsertIfNeeded(operation)
        }
    }

    private func enqueueLatestUpsert(
        database: LocalDatabase,
        profileID: UUID,
        entityType: SyncEntityType,
        entityID: UUID,
        revision: Int64
    ) async throws {
        try await database.enqueueLatestUpsert(
            makeUpsert(
                profileID: profileID,
                entityType: entityType,
                entityID: entityID,
                revision: revision,
                at: Date()
            )
        )
    }

    private func weekdaysMask(for plan: WakeAlarmPlan) -> Int {
        plan.weekdays.reduce(into: 0) { mask, weekday in
            mask |= 1 << (weekday - 1)
        }
    }

    private func makeUpsert(
        profileID: UUID,
        entityType: SyncEntityType,
        entityID: UUID,
        revision: Int64,
        at date: Date
    ) -> SynchronizationOperation {
        SynchronizationOperation(
            id: UUID(),
            profileID: profileID,
            entityType: entityType,
            entityID: entityID,
            operation: .upsert,
            idempotencyKey: UUID(),
            baseRevision: max(0, revision - 1),
            localRevision: revision,
            state: .pending,
            attemptCount: 0,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func synchronizePending(profileID: UUID, userID: UUID) async {
        guard let remote, let database = try? databaseInstance() else { return }
        let engine = SynchronizationEngine(
            database: database,
            payloadProvider: LocalDatabaseOutboundPayloadProvider(database: database),
            remote: remote,
            clock: SystemPhase1BClock(),
            random: SystemUnitIntervalRandom()
        )
        for _ in 0 ..< 50 {
            guard await (try? engine.synchronizeNext(
                profileID: profileID,
                authenticatedUserID: userID
            )) == true else {
                return
            }
        }
    }

    private func databaseInstance() throws -> LocalDatabase {
        if let database {
            return database
        }
        let url = try location.databaseURL()
        let opened = try LocalDatabase(path: url.path)
        try protection.applyProtection(to: url, kind: .localDatabase)
        database = opened
        return opened
    }

    private func exportService() -> LocalExportService {
        LocalExportService(
            clock: SystemPhase1BClock(),
            identifier: SystemIdentifierGenerator(),
            protection: SystemProtectedFileApplicator()
        )
    }
}

actor AccountBoundPreferencesStore {
    private let keychain: any KeychainClient
    private let service = "com.satyamshree.spc.phase1.preferences"

    init(keychain: any KeychainClient = SystemKeychainClient()) {
        self.keychain = keychain
    }

    func read(userID: UUID) throws -> SleepSchedule? {
        guard let data = try keychain.read(service: service, account: userID.uuidString) else {
            return nil
        }
        return try JSONDecoder().decode(SleepSchedule.self, from: data)
    }

    func write(_ schedule: SleepSchedule, userID: UUID) throws {
        try keychain.write(
            JSONEncoder().encode(schedule),
            service: service,
            account: userID.uuidString
        )
    }

    func delete(userID: UUID) throws {
        try keychain.delete(service: service, account: userID.uuidString)
    }
}
