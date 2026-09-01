import Foundation

/// # Deletion Foundation & Data Rights
///
/// This file defines the coordinators and contracts for user-controlled sign-out, local data deletion,
/// and complete remote account deletion:
///
/// - `SignOutCoordinator`: Phase 1B coordinator managing explicit local-copy choices and delegating provider grant
///   revocations through `AuthenticationCoordinator` (Stack A).
/// - `AccountDeletionCoordinator`: Coordinates the two-phase account deletion workflow: verified remote RPC
///   deletion via `AccountDeletionGateway`, session termination (`AccountDeletionSessionSigningOut` / `OAuthSessionServicing`),
///   and local data purge via `LocalAccountDataRemoving`.
/// - `LocalDataDeletionCoordinator`: Orchestrates the total erasure of wake alarms, downloaded audio, exports,
///   Keychain session records, and SQLite profile data.
///
/// See `docs/PHASE_SIGN_IN_FLOW.md` Section 9 for complete data-rights workflow diagrams.
nonisolated enum SignOutLocalDataChoice: String, Codable, CaseIterable, Sendable {
    case keepProtectedLocalCopy
    case removeAccountDataFromDevice
}

nonisolated enum PendingWorkSignOutChoice: String, Codable, CaseIterable, Sendable {
    case synchronizeNow
    case keepLocallyAndSignOut
    case cancel
}

nonisolated enum AccountDeletionState: Equatable, Sendable {
    case idle
    case reauthenticationRequired
    case deleting(requestID: UUID)
    case failedRecoverable(requestID: UUID)
    case completed
}

nonisolated protocol AppCreatedAlarmRemoving: Sendable {
    func removeAllAppCreatedAlarms() async throws
}

nonisolated protocol ProtectedLocalFilesRemoving: Sendable {
    func removeDownloadedAudioAndExports() async throws
}

nonisolated protocol LocalAccountDataRemoving: Sendable {
    func deleteAllLocalData() async throws
}

nonisolated protocol AccountDeletionSessionSigningOut: Sendable {
    func signOut() async throws
}

nonisolated protocol AccountDeletionGateway: Sendable {
    func deleteAccount(
        requestID: UUID,
        accessToken: String,
        retryToken: String?
    ) async throws -> String?
}

nonisolated enum AccountDeletionGatewayError: Error, Equatable, Sendable {
    case recoverable(retryToken: String?)
    case rejected
}

nonisolated enum DeletionError: Error, Equatable, Sendable {
    case recentReauthenticationRequired
    case wrongAccount
    case localCleanupFailed
    case remoteDeletionFailedRecoverable
    case remoteDeletionRejected
}

nonisolated enum AccountDeletionFeedback: Sendable {
    static let completed = "Your account was deleted. Local data was removed and you were signed out."
    static let recoverable = "Account deletion could not finish. Local data was kept. Retry to resume the same request."
}

nonisolated struct SignOutRequest: Sendable {
    let profileID: UUID
    let userID: UUID
    let pendingWork: Bool
    let pendingChoice: PendingWorkSignOutChoice?
    let localChoice: SignOutLocalDataChoice
    let providerRevocationCredential: ProviderGrantCredential?
}

actor SignOutCoordinator {
    private let database: LocalDatabase
    private let authentication: AuthenticationCoordinator

    init(database: LocalDatabase, authentication: AuthenticationCoordinator) {
        self.database = database
        self.authentication = authentication
    }

    func signOut(_ request: SignOutRequest) async throws {
        if request.pendingWork {
            guard let pendingChoice = request.pendingChoice else {
                throw DeletionError.localCleanupFailed
            }
            switch pendingChoice {
            case .cancel, .synchronizeNow:
                throw CancellationError()
            case .keepLocallyAndSignOut:
                break
            }
        }

        _ = try await authentication.signOut(
            providerRevocationCredential: request.providerRevocationCredential
        )
        switch request.localChoice {
        case .keepProtectedLocalCopy:
            try await database.protectFormerAccountData(
                profileID: request.profileID,
                expectedUserID: request.userID
            )
        case .removeAccountDataFromDevice:
            try await database.removeProfileFromDevice(
                profileID: request.profileID,
                expectedUserID: request.userID
            )
        }
    }
}

actor LocalDataDeletionCoordinator: LocalAccountDataRemoving {
    private let database: LocalDatabase
    private let sessionStore: any SessionSecretStore
    private let alarms: any AppCreatedAlarmRemoving
    private let files: any ProtectedLocalFilesRemoving

    init(
        database: LocalDatabase,
        sessionStore: any SessionSecretStore,
        alarms: any AppCreatedAlarmRemoving,
        files: any ProtectedLocalFilesRemoving
    ) {
        self.database = database
        self.sessionStore = sessionStore
        self.alarms = alarms
        self.files = files
    }

    func deleteAllLocalData() async throws {
        do {
            try await alarms.removeAllAppCreatedAlarms()
            try await files.removeDownloadedAudioAndExports()
            try sessionStore.delete()
            try await database.deleteAllLocalData()
        } catch {
            throw DeletionError.localCleanupFailed
        }
    }
}

actor AccountDeletionCoordinator {
    private let remote: any AccountDeletionGateway
    private let localDeletion: any LocalAccountDataRemoving
    private let sessionSignOut: any AccountDeletionSessionSigningOut
    private let identifier: any IdentifierGenerating
    private let clock: any Phase1BClock
    private var requestID: UUID?
    private var retryToken: String?
    private var sessionSignedOut = false
    private(set) var state: AccountDeletionState = .idle

    init(
        remote: any AccountDeletionGateway,
        localDeletion: any LocalAccountDataRemoving,
        sessionSignOut: any AccountDeletionSessionSigningOut,
        identifier: any IdentifierGenerating,
        clock: any Phase1BClock
    ) {
        self.remote = remote
        self.localDeletion = localDeletion
        self.sessionSignOut = sessionSignOut
        self.identifier = identifier
        self.clock = clock
    }

    // The deletion coordinator preserves explicit retry and cleanup states.
    // swiftlint:disable cyclomatic_complexity
    func deleteAccount(
        session: AuthenticationSessionMaterial,
        reauthentication: RecentReauthentication,
        removeLocalData: Bool
    ) async throws {
        guard reauthentication.userID == session.userID else {
            throw DeletionError.wrongAccount
        }
        guard reauthentication.provider == session.provider else {
            throw DeletionError.wrongAccount
        }
        guard reauthentication.isValid(now: clock.now()) || retryToken != nil else {
            state = .reauthenticationRequired
            throw DeletionError.recentReauthenticationRequired
        }
        let requestID = self.requestID ?? identifier.next()
        self.requestID = requestID
        state = .deleting(requestID: requestID)
        do {
            let issuedRetryToken = try await remote.deleteAccount(
                requestID: requestID,
                accessToken: session.accessToken,
                retryToken: retryToken
            )
            if let issuedRetryToken {
                retryToken = issuedRetryToken
            }
            if !sessionSignedOut {
                try await sessionSignOut.signOut()
                sessionSignedOut = true
            }
            if removeLocalData {
                try await localDeletion.deleteAllLocalData()
            }
            retryToken = nil
            self.requestID = nil
            sessionSignedOut = false
            state = .completed
        } catch is CancellationError {
            state = .failedRecoverable(requestID: requestID)
            throw CancellationError()
        } catch let error as AccountDeletionGatewayError {
            if case let .recoverable(nextRetryToken) = error {
                retryToken = nextRetryToken ?? retryToken
                state = .failedRecoverable(requestID: requestID)
                throw DeletionError.remoteDeletionFailedRecoverable
            }
            self.requestID = nil
            retryToken = nil
            sessionSignedOut = false
            state = .idle
            throw DeletionError.remoteDeletionRejected
        } catch let error as DeletionError {
            state = .failedRecoverable(requestID: requestID)
            throw error
        } catch {
            state = .failedRecoverable(requestID: requestID)
            throw DeletionError.remoteDeletionFailedRecoverable
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
