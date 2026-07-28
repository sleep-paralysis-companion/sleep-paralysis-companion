nonisolated enum ContextualPermissionKind: String, CaseIterable, Sendable {
    case alarms
}

nonisolated enum ContextualPermissionState: String, CaseIterable, Sendable {
    case notRequested
    case denied
    case unsupported
    case available
}

nonisolated protocol ContextualPermissionStateProviding: Sendable {
    func state(for permission: ContextualPermissionKind) async -> ContextualPermissionState
}

nonisolated struct Phase1CPermissionStateProvider: ContextualPermissionStateProviding {
    func state(for permission: ContextualPermissionKind) async -> ContextualPermissionState {
        _ = permission
        return .notRequested
    }
}
