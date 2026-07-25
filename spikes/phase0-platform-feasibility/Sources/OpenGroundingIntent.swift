import AppIntents

struct OpenGroundingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open test grounding"
    static var description = IntentDescription(
        "Opens the disposable Phase 0 grounding fixture."
    )
    static var openAppWhenRun = true

    @Parameter(title: "Alarm identifier")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "pendingGroundingRoute")
        UserDefaults.standard.set(alarmID, forKey: "lastIntentAlarmID")
        return .result()
    }
}

