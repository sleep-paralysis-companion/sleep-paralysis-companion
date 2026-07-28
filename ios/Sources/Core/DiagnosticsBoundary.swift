import Foundation

nonisolated enum DiagnosticEvent: String, CaseIterable, Sendable {
    case appStartResult
    case alarmOperationResult
    case systemEntryResult
    case audioOperationResult
    case syncOperationResult
    case purchaseOperationResult
    case exportDeleteResult
}

nonisolated enum DiagnosticResultCategory: String, CaseIterable, Sendable {
    case success
    case cancelled
    case unavailable
    case failedRecoverable
    case denied
}

nonisolated struct DiagnosticRecord: Equatable, Sendable {
    let event: DiagnosticEvent
    let result: DiagnosticResultCategory
    let coarseOperationCategory: String
}

nonisolated protocol DiagnosticsRecording: Sendable {
    func record(_ record: DiagnosticRecord)
}

nonisolated struct DisabledDiagnosticsRecorder: DiagnosticsRecording {
    func record(_ record: DiagnosticRecord) {
        _ = record
    }
}
