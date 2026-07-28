import Foundation

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

nonisolated protocol AccountDeletionGateway: Sendable {
    func deleteAccount(
        requestID: UUID,
        accessToken: String,
        retryToken: String?
    ) async throws
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

actor LocalDataDeletionCoordinator {
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
    private let localDeletion: LocalDataDeletionCoordinator
    private let identifier: any IdentifierGenerating
    private let clock: any Phase1BClock
    private var retryToken: String?
    private(set) var state: AccountDeletionState = .idle

    init(
        remote: any AccountDeletionGateway,
        localDeletion: LocalDataDeletionCoordinator,
        identifier: any IdentifierGenerating,
        clock: any Phase1BClock
    ) {
        self.remote = remote
        self.localDeletion = localDeletion
        self.identifier = identifier
        self.clock = clock
    }

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
        guard reauthentication.isValid(now: clock.now()) else {
            state = .reauthenticationRequired
            throw DeletionError.recentReauthenticationRequired
        }
        let requestID: UUID = switch state {
        case let .failedRecoverable(existing):
            existing
        default:
            identifier.next()
        }
        state = .deleting(requestID: requestID)
        do {
            try await remote.deleteAccount(
                requestID: requestID,
                accessToken: session.accessToken,
                retryToken: retryToken
            )
            if removeLocalData {
                try await localDeletion.deleteAllLocalData()
            }
            retryToken = nil
            state = .completed
        } catch is CancellationError {
            state = .failedRecoverable(requestID: requestID)
            throw CancellationError()
        } catch let error as AccountDeletionGatewayError {
            if case let .recoverable(nextRetryToken) = error {
                retryToken = nextRetryToken ?? retryToken
            }
            state = .failedRecoverable(requestID: requestID)
            throw DeletionError.remoteDeletionFailedRecoverable
        } catch {
            state = .failedRecoverable(requestID: requestID)
            throw DeletionError.remoteDeletionFailedRecoverable
        }
    }
}
