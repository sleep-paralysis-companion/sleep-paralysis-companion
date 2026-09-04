import Foundation

/// A small UI-facing adapter for the schedules feature.
///
/// The schedule engine will eventually own the persisted `AlarmSchedule`,
/// `AlarmScheduleKind`, and `AlarmAudioSelection` values. Keeping this adapter
/// local to the feature lets the list and editor be previewed and integrated
/// without coupling them to persistence or scheduling services.
nonisolated enum ScheduleUIKind: String, CaseIterable, Codable, Hashable, Sendable {
    case sleep
    case wakeOnly

    var title: String {
        switch self {
        case .sleep:
            "Sleep schedule"
        case .wakeOnly:
            "Wake-only alarm"
        }
    }
}

nonisolated enum ScheduleUIAudioSelection: Equatable, Identifiable, Sendable {
    case bundled(id: String, title: String)
    case catalog(id: String, title: String, isAvailable: Bool)
    case personal(id: UUID, title: String, isAvailable: Bool)
    case unavailable

    var id: String {
        switch self {
        case let .bundled(id, _):
            "bundled:\(id)"
        case let .catalog(id, _, _):
            "catalog:\(id)"
        case let .personal(id, _, _):
            "personal:\(id.uuidString)"
        case .unavailable:
            "unavailable"
        }
    }

    var title: String {
        switch self {
        case let .bundled(_, title), let .catalog(_, title, _), let .personal(_, title, _):
            title
        case .unavailable:
            "Audio unavailable on this device"
        }
    }

    var sourceTitle: String {
        switch self {
        case .bundled:
            "Bundled"
        case .catalog:
            "Catalog"
        case .personal:
            "Personal recording"
        case .unavailable:
            "Unavailable"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .bundled:
            true
        case let .catalog(_, _, isAvailable), let .personal(_, _, isAvailable):
            isAvailable
        case .unavailable:
            false
        }
    }
}

nonisolated struct ScheduleUIModel: Identifiable, Equatable, Sendable {
    static let maximumCount = 8

    let id: UUID
    var name: String
    var kind: ScheduleUIKind
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var wakeHour: Int
    var wakeMinute: Int
    /// Sunday is bit 0, matching `Calendar`'s weekday component.
    var repeatWeekdaysMask: Int
    var bedtimeReminderLeadMinutes: Int?
    var preWakeReminderLeadMinutes: Int?
    var wakeAudio: ScheduleUIAudioSelection
    var isEnabled: Bool
    var snoozeMinutes: Int?
    /// A non-nil date marks a one-time wake-only alarm.
    var oneTimeDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        kind: ScheduleUIKind,
        bedtimeHour: Int,
        bedtimeMinute: Int,
        wakeHour: Int,
        wakeMinute: Int,
        repeatWeekdaysMask: Int,
        bedtimeReminderLeadMinutes: Int?,
        preWakeReminderLeadMinutes: Int?,
        wakeAudio: ScheduleUIAudioSelection,
        isEnabled: Bool,
        snoozeMinutes: Int? = 9,
        oneTimeDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.repeatWeekdaysMask = repeatWeekdaysMask
        self.bedtimeReminderLeadMinutes = bedtimeReminderLeadMinutes
        self.preWakeReminderLeadMinutes = preWakeReminderLeadMinutes
        self.wakeAudio = wakeAudio
        self.isEnabled = isEnabled
        self.snoozeMinutes = snoozeMinutes
        self.oneTimeDate = oneTimeDate
    }

    static let newSleep = ScheduleUIModel(
        name: "New sleep schedule",
        kind: .sleep,
        bedtimeHour: 22,
        bedtimeMinute: 30,
        wakeHour: 6,
        wakeMinute: 30,
        repeatWeekdaysMask: 0b0111_1111,
        bedtimeReminderLeadMinutes: 15,
        preWakeReminderLeadMinutes: 15,
        wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
        isEnabled: false
    )

    static let newWakeOnly = ScheduleUIModel(
        name: "One-time alarm",
        kind: .wakeOnly,
        bedtimeHour: 0,
        bedtimeMinute: 0,
        wakeHour: 6,
        wakeMinute: 0,
        repeatWeekdaysMask: 0,
        bedtimeReminderLeadMinutes: nil,
        preWakeReminderLeadMinutes: nil,
        wakeAudio: .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise"),
        isEnabled: false,
        oneTimeDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)
    )

    var isWakeOnly: Bool {
        kind == .wakeOnly
    }

    var isValid: Bool {
        let validTime = (0 ... 23).contains(bedtimeHour)
            && (0 ... 59).contains(bedtimeMinute)
            && (0 ... 23).contains(wakeHour)
            && (0 ... 59).contains(wakeMinute)
        switch kind {
        case .sleep:
            return validTime && repeatWeekdaysMask != 0
        case .wakeOnly:
            return validTime && oneTimeDate != nil
        }
    }

    func includes(weekday: Int) -> Bool {
        guard (1 ... 7).contains(weekday) else { return false }
        return repeatWeekdaysMask & (1 << (weekday - 1)) != 0
    }
}

nonisolated extension ScheduleUIModel {
    init(_ schedule: AlarmSchedule) {
        let audio: ScheduleUIAudioSelection = switch schedule.wakeAudio {
        case let .some(selection) where selection.availability == .unavailableOnThisDevice:
            .unavailable
        case let .some(selection):
            switch selection.reference {
            case let .bundled(resourceName):
                .bundled(id: resourceName, title: "Gentle rise")
            case let .catalog(assetID, _):
                .catalog(id: assetID, title: "Downloaded sound", isAvailable: selection.isAvailableOnThisDevice)
            case let .personal(clipID):
                .personal(id: clipID, title: "Personal recording", isAvailable: selection.isAvailableOnThisDevice)
            }
        case .none:
            .bundled(id: SystemAudioAssets.defaultAlarmAssetID, title: "Gentle rise")
        }

        self.init(
            id: schedule.id,
            name: schedule.name,
            kind: schedule.kind == .sleep ? .sleep : .wakeOnly,
            bedtimeHour: schedule.bedtimeHour ?? 22,
            bedtimeMinute: schedule.bedtimeMinute ?? 30,
            wakeHour: schedule.wakeHour,
            wakeMinute: schedule.wakeMinute,
            repeatWeekdaysMask: schedule.weekdaysMask,
            bedtimeReminderLeadMinutes: schedule.bedtimeReminderLeadMinutes,
            preWakeReminderLeadMinutes: schedule.wakeReminderLeadMinutes,
            wakeAudio: audio,
            isEnabled: schedule.isEnabled,
            oneTimeDate: schedule.oneTimeDate?.date()
        )
    }

    func domainValue(
        profileID: UUID,
        existing: AlarmSchedule?,
        sortOrder: Int,
        now: Date = Date()
    ) -> AlarmSchedule {
        let kind: AlarmScheduleKind = switch self.kind {
        case .sleep: .sleep
        case .wakeOnly: oneTimeDate == nil ? .wakeOnlyRecurring : .wakeOnlyOneTime
        }
        let audio: AlarmAudioSelection = switch wakeAudio {
        case let .bundled(id, _):
            .init(
                reference: .bundled(resourceName: id == SystemAudioAssets.defaultAlarmAssetID
                    ? SystemAudioAssets.defaultAlarmFileName : id),
                localFileName: id == SystemAudioAssets.defaultAlarmAssetID
                    ? SystemAudioAssets.defaultAlarmFileName : id
            )
        case let .catalog(id, _, isAvailable):
            .init(
                reference: .catalog(assetID: id, version: catalogVersion(assetID: id, existing: existing)),
                localFileName: existing?.wakeAudio?.localFileName
                    ?? (AlarmSoundSelectionStore.selectedAlarmAssetID() == id
                        ? AlarmSoundSelectionStore.selectedAlarmSoundFileName()
                        : nil),
                availability: isAvailable ? .available : .unavailableOnThisDevice
            )
        case let .personal(id, _, isAvailable):
            .init(
                reference: .personal(clipID: id),
                localFileName: existing?.wakeAudio?.localFileName,
                availability: isAvailable ? .available : .unavailableOnThisDevice
            )
        case .unavailable:
            existing?.wakeAudio.map {
                var selection = $0
                selection.availability = .unavailableOnThisDevice
                return selection
            } ?? .defaultBundled
        }
        let resolvedName: String = {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return self.kind == .sleep ? "Sleep schedule" : "Wake up"
        }()
        return AlarmSchedule(
            id: id,
            profileID: profileID,
            name: resolvedName,
            kind: kind,
            bedtimeHour: kind == .sleep ? bedtimeHour : nil,
            bedtimeMinute: kind == .sleep ? bedtimeMinute : nil,
            wakeHour: wakeHour,
            wakeMinute: wakeMinute,
            weekdaysMask: kind == .wakeOnlyOneTime ? 0 : repeatWeekdaysMask,
            oneTimeDate: kind == .wakeOnlyOneTime ? oneTimeDate.map { AlarmLocalDate(date: $0) } : nil,
            bedtimeReminderLeadMinutes: kind == .sleep ? bedtimeReminderLeadMinutes : nil,
            wakeReminderLeadMinutes: preWakeReminderLeadMinutes,
            finalWakeAlarmEnabled: true,
            wakeAudio: audio,
            isEnabled: isEnabled,
            sortOrder: sortOrder,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            revision: (existing?.revision ?? 0) + 1
        )
    }

    private func catalogVersion(assetID: String, existing: AlarmSchedule?) -> Int {
        if case let .catalog(existingID, version)? = existing?.wakeAudio?.reference,
           existingID == assetID
        {
            return version
        }
        guard AlarmSoundSelectionStore.selectedAlarmAssetID() == assetID,
              let fileName = AlarmSoundSelectionStore.selectedAlarmSoundFileName(),
              let marker = fileName.range(of: "-v", options: .backwards),
              let suffix = fileName[marker.upperBound...].split(separator: ".").first,
              let version = Int(suffix)
        else { return 1 }
        return version
    }
}
