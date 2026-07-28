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

nonisolated struct RecentReauthentication: Equatable, Sendable {
    let userID: UUID
    let authenticatedAt: Date

    func isValid(now: Date, maximumAge: TimeInterval = 5 * 60) -> Bool {
        authenticatedAt <= now && now.timeIntervalSince(authenticatedAt) <= maximumAge
    }
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
    func deleteAccount(requestID: UUID, accessToken: String) async throws
}

nonisolated enum DeletionError: Error, Equatable, Sendable {
    case recentReauthenticationRequired
    case wrongAccount
    case localCleanupFailed
    case remoteDeletionFailedRecoverable
}

actor SignOutCoordinator {
    private let database: LocalDatabase
    private let authentication: AuthenticationCoordinator

    init(database: LocalDatabase, authentication: AuthenticationCoordinator) {
        self.database = database
        self.authentication = authentication
    }

    func signOut(
        profileID: UUID,
        userID: UUID,
        pendingWork: Bool,
        pendingChoice: PendingWorkSignOutChoice?,
        localChoice: SignOutLocalDataChoice,
        revokeProvider: Bool
    ) async throws {
        if pendingWork {
            guard let pendingChoice else {
                throw DeletionError.localCleanupFailed
            }
            switch pendingChoice {
            case .cancel, .synchronizeNow:
                throw CancellationError()
            case .keepLocallyAndSignOut:
                break
            }
        }

        try await authentication.signOut(revokeProvider: revokeProvider)
        switch localChoice {
        case .keepProtectedLocalCopy:
            try await database.protectFormerAccountData(
                profileID: profileID,
                expectedUserID: userID
            )
        case .removeAccountDataFromDevice:
            try await database.removeProfileFromDevice(
                profileID: profileID,
                expectedUserID: userID
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
        guard reauthentication.isValid(now: clock.now()) else {
            state = .reauthenticationRequired
            throw DeletionError.recentReauthenticationRequired
        }
        let requestID: UUID
        switch state {
        case let .failedRecoverable(existing):
            requestID = existing
        default:
            requestID = identifier.next()
        }
        state = .deleting(requestID: requestID)
        do {
            try await remote.deleteAccount(requestID: requestID, accessToken: session.accessToken)
            if removeLocalData {
                try await localDeletion.deleteAllLocalData()
            }
            state = .completed
        } catch is CancellationError {
            state = .failedRecoverable(requestID: requestID)
            throw CancellationError()
        } catch {
            state = .failedRecoverable(requestID: requestID)
            throw DeletionError.remoteDeletionFailedRecoverable
        }
    }
}
