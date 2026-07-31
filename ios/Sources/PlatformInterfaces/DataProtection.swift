import Foundation

nonisolated enum ProtectedFileKind: Sendable {
    case localDatabase
    case sensitiveTemporaryExport
    case downloadedAudioCache
    case personalAudio
}

nonisolated struct DataProtectionPolicy: Sendable {
    func protection(for kind: ProtectedFileKind) -> FileProtectionType {
        switch kind {
        case .localDatabase:
            .completeUntilFirstUserAuthentication
        case .sensitiveTemporaryExport:
            .complete
        case .downloadedAudioCache, .personalAudio:
            .completeUntilFirstUserAuthentication
        }
    }
}

nonisolated protocol ProtectedFileApplying: Sendable {
    func applyProtection(to url: URL, kind: ProtectedFileKind) throws
}

nonisolated struct SystemProtectedFileApplicator: ProtectedFileApplying {
    private let policy: DataProtectionPolicy

    init(policy: DataProtectionPolicy = DataProtectionPolicy()) {
        self.policy = policy
    }

    func applyProtection(to url: URL, kind: ProtectedFileKind) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: policy.protection(for: kind)],
            ofItemAtPath: url.path
        )
    }
}
