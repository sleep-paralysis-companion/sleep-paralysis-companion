import Foundation

nonisolated enum GuestMergeChoice: String, Codable, CaseIterable, Sendable {
    case devicePreferences
    case accountPreferences
    case cancel
}

nonisolated struct ConversionCheckpoint: Equatable, Sendable {
    let conversionID: UUID
    let profileID: UUID
    let expectedUserID: UUID
    var state: AccountLinkState
    var mergeChoice: GuestMergeChoice?
    let startedAt: Date
    var updatedAt: Date
}

nonisolated struct RemoteAccountSummary: Equatable, Sendable {
    let submittedCheckInCount: Int
    let hasSettingsDifference: Bool
    let hasAlarmDifference: Bool
    let lastSynchronizedAt: Date?

    var hasRemoteData: Bool {
        submittedCheckInCount > 0 || hasSettingsDifference || hasAlarmDifference
    }
}

nonisolated struct GuestConversionCommit: Equatable, Sendable {
    let conversionID: UUID
    let userID: UUID
    let committedAt: Date
}

nonisolated protocol GuestConversionGateway: Sendable {
    func inspectAccount(userID: UUID) async throws -> RemoteAccountSummary
    func convert(
        conversionID: UUID,
        profileID: UUID,
        userID: UUID,
        mergeChoice: GuestMergeChoice?
    ) async throws -> GuestConversionCommit
}

nonisolated enum GuestConversionResult: Equatable, Sendable {
    case awaitingMergeChoice(RemoteAccountSummary)
    case linked
    case stayedLocal
    case failedRecoverable
}

actor GuestConversionCoordinator {
    private let database: LocalDatabase
    private let remote: any GuestConversionGateway
    private let identifier: any IdentifierGenerating
    private let clock: any Phase1BClock

    init(
        database: LocalDatabase,
        remote: any GuestConversionGateway,
        identifier: any IdentifierGenerating,
        clock: any Phase1BClock
    ) {
        self.database = database
        self.remote = remote
        self.identifier = identifier
        self.clock = clock
    }

    func start(
        profileID: UUID,
        session: AuthenticationSessionMaterial
    ) async throws -> GuestConversionResult {
        let checkpoint = ConversionCheckpoint(
            conversionID: identifier.next(),
            profileID: profileID,
            expectedUserID: session.userID,
            state: .authenticating,
            mergeChoice: nil,
            startedAt: clock.now(),
            updatedAt: clock.now()
        )
        try await database.beginConversion(checkpoint)
        do {
            try Task.checkCancellation()
            let summary = try await remote.inspectAccount(userID: session.userID)
            if summary.hasRemoteData {
                var awaiting = checkpoint
                awaiting.state = .awaitingMergeChoice
                awaiting.updatedAt = clock.now()
                try await database.saveConversionCheckpoint(awaiting)
                return .awaitingMergeChoice(summary)
            }
            return try await commit(checkpoint: checkpoint, session: session, mergeChoice: nil)
        } catch is CancellationError {
            try await database.cancelConversion(profileID: profileID)
            throw CancellationError()
        } catch {
            var failed = checkpoint
            failed.state = .failedRecoverable
            failed.updatedAt = clock.now()
            try await database.saveConversionCheckpoint(failed)
            return .failedRecoverable
        }
    }

    func continueConversion(
        profileID: UUID,
        session: AuthenticationSessionMaterial,
        choice: GuestMergeChoice
    ) async throws -> GuestConversionResult {
        guard var checkpoint = try await database.conversionCheckpoint(profileID: profileID) else {
            throw AuthenticationError.missingChallenge
        }
        guard checkpoint.expectedUserID == session.userID else {
            throw AuthenticationError.wrongAccount
        }
        if choice == .cancel {
            try await database.cancelConversion(profileID: profileID)
            return .stayedLocal
        }
        checkpoint.mergeChoice = choice
        checkpoint.state = .converting
        checkpoint.updatedAt = clock.now()
        try await database.saveConversionCheckpoint(checkpoint)
        return try await commit(checkpoint: checkpoint, session: session, mergeChoice: choice)
    }

    func resume(profileID: UUID, session: AuthenticationSessionMaterial) async throws -> GuestConversionResult {
        guard let checkpoint = try await database.conversionCheckpoint(profileID: profileID) else {
            return .stayedLocal
        }
        guard checkpoint.expectedUserID == session.userID else {
            throw AuthenticationError.wrongAccount
        }
        guard checkpoint.state == .converting || checkpoint.state == .failedRecoverable else {
            return .failedRecoverable
        }
        return try await commit(
            checkpoint: checkpoint,
            session: session,
            mergeChoice: checkpoint.mergeChoice
        )
    }

    private func commit(
        checkpoint: ConversionCheckpoint,
        session: AuthenticationSessionMaterial,
        mergeChoice: GuestMergeChoice?
    ) async throws -> GuestConversionResult {
        let commit = try await remote.convert(
            conversionID: checkpoint.conversionID,
            profileID: checkpoint.profileID,
            userID: session.userID,
            mergeChoice: mergeChoice
        )
        guard commit.conversionID == checkpoint.conversionID,
              commit.userID == checkpoint.expectedUserID
        else {
            throw AuthenticationError.wrongAccount
        }
        let binding = AccountBinding(
            profileID: checkpoint.profileID,
            userID: session.userID,
            provider: session.provider,
            maskedIdentifier: nil,
            linkedAt: commit.committedAt,
            sessionExpiresAt: session.expiresAt,
            requiresReauthentication: false
        )
        try await database.finalizeConversion(binding: binding, conversionID: checkpoint.conversionID)
        return .linked
    }
}
