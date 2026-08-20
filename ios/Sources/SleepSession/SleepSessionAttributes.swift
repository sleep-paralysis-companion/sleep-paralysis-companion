import ActivityKit
import Foundation

nonisolated struct SleepSessionAttributes: ActivityAttributes, Hashable, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let audioStatus: SleepSessionAudioStatus
    }

    let startedAt: Date
}

nonisolated enum SleepSessionAudioStatus: String, Codable, Hashable, Sendable {
    case ready
    case playing
    case paused
}
