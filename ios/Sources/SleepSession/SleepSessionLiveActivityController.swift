import ActivityKit
import Foundation

@MainActor
final class SleepSessionLiveActivityController {
    private var activity: Activity<SleepSessionAttributes>?

    var activeStartedAt: Date? {
        activeActivity?.attributes.startedAt
    }

    func start(startedAt: Date) throws {
        if let activeActivity {
            activity = activeActivity
            return
        }

        let attributes = SleepSessionAttributes(startedAt: startedAt)
        let state = SleepSessionAttributes.ContentState(audioStatus: .ready)
        activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(audioStatus: SleepSessionAudioStatus) async {
        guard let activeActivity else { return }
        let state = SleepSessionAttributes.ContentState(audioStatus: audioStatus)
        await activeActivity.update(ActivityContent(state: state, staleDate: nil))
        activity = activeActivity
    }

    func end() async {
        guard let activeActivity else { return }
        let finalState = SleepSessionAttributes.ContentState(audioStatus: .ready)
        await activeActivity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        activity = nil
    }

    private var activeActivity: Activity<SleepSessionAttributes>? {
        if let activity, activity.activityState == .active {
            return activity
        }
        return Activity<SleepSessionAttributes>.activities.first { $0.activityState == .active }
    }
}
