import Foundation

nonisolated enum FeatureIntroductionPage: Int, CaseIterable, Identifiable, Sendable {
    case gentleWake
    case postEpisodeSupport
    case familiarVoice

    var id: Int {
        rawValue
    }
}

nonisolated enum AuthenticationPresentationState: Equatable, Sendable {
    case ready
    case processing(AuthenticationProvider)
    case cancelled
    case failed
    case configurationRequired
    case sessionExpired
}

/// The type of alert represented by an alarm schedule.
///
/// A sleep schedule has a bedtime and a wake time. A wake-only recurring
/// schedule is useful for a regular morning alarm, while a wake-only one-time
/// schedule keeps the one-off alarm flow deliberately small.
nonisolated enum AlarmScheduleKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case wakeOnlyRecurring = "wake_only_recurring"
    case wakeOnlyOneTime = "wake_only_one_time"

    var isRecurring: Bool {
        self != .wakeOnlyOneTime
    }

    var isWakeOnly: Bool {
        self != .sleep
    }
}

/// A calendar date without a timezone. Dates stored on an alarm schedule are
/// intentionally local dates so a one-time alarm does not move when a person
/// changes timezone before it fires.
nonisolated struct AlarmLocalDate: Codable, Equatable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    func date(in calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    func addingDays(_ value: Int, calendar: Calendar = .current) -> AlarmLocalDate {
        guard let date = date(in: calendar),
              let shifted = calendar.date(byAdding: .day, value: value, to: date)
        else {
            return self
        }
        return AlarmLocalDate(date: shifted, calendar: calendar)
    }

    var iso8601String: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var isValid: Bool {
        guard (1 ... 12).contains(month), (1 ... 31).contains(day) else {
            return false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let value = date(in: calendar) else { return false }
        let components = calendar.dateComponents([.year, .month, .day], from: value)
        return components.year == year
            && components.month == month
            && components.day == day
    }
}

/// A stable reference to an audio asset. The reference is safe to synchronize;
/// the local file name is deliberately kept separate because personal audio
/// is not uploaded with a schedule.
nonisolated enum AlarmAudioReference: Codable, Equatable, Hashable, Sendable {
    case bundled(resourceName: String)
    case catalog(assetID: String, version: Int)
    case personal(clipID: UUID)

    var stableIdentifier: String {
        switch self {
        case let .bundled(resourceName):
            "bundled:\(resourceName)"
        case let .catalog(assetID, version):
            "catalog:\(assetID):\(version)"
        case let .personal(clipID):
            "personal:\(clipID.uuidString)"
        }
    }
}

nonisolated enum AlarmAudioAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case unavailableOnThisDevice = "unavailable_on_this_device"

    var accessibilityDescription: String {
        switch self {
        case .available:
            "Available on this device"
        case .unavailableOnThisDevice:
            "Audio unavailable on this device"
        }
    }
}

/// The selected wake sound plus its device-local resolution state. A missing
/// personal/catalog asset is represented explicitly; scheduling code must not
/// silently substitute the bundled sound.
nonisolated struct AlarmAudioSelection: Codable, Equatable, Sendable {
    var reference: AlarmAudioReference
    var localFileName: String?
    var availability: AlarmAudioAvailability

    init(
        reference: AlarmAudioReference,
        localFileName: String? = nil,
        availability: AlarmAudioAvailability = .available
    ) {
        self.reference = reference
        self.localFileName = localFileName
        self.availability = availability
    }

    static let defaultBundled = AlarmAudioSelection(
        reference: .bundled(resourceName: "SPCWakeUpGentleLoop.caf"),
        localFileName: "SPCWakeUpGentleLoop.caf"
    )

    var isAvailableOnThisDevice: Bool {
        availability == .available
    }
}

/// A named, independently schedulable alarm. The model is deliberately
/// self-contained so every alarm can carry its own reminder timings, repeat
/// days, and sound selection.
nonisolated struct AlarmSchedule: Codable, Equatable, Identifiable, Sendable {
    static let maximumCount = 8
    static let validReminderLeadOptions = [0, 5, 10, 15, 30, 60]
    static let validWakeAudioLeadOptions = [5, 10, 15, 30]

    let id: UUID
    var profileID: UUID?
    var name: String
    var kind: AlarmScheduleKind
    var bedtimeHour: Int?
    var bedtimeMinute: Int?
    var wakeHour: Int
    var wakeMinute: Int
    /// Bits 0...6 map to Sunday...Saturday, matching Calendar weekday values.
    var weekdaysMask: Int
    var oneTimeDate: AlarmLocalDate?
    var bedtimeReminderLeadMinutes: Int?
    var wakeReminderLeadMinutes: Int?
    var finalWakeAlarmEnabled: Bool
    var wakeAudio: AlarmAudioSelection?
    var isEnabled: Bool
    var sortOrder: Int
    let createdAt: Date
    var updatedAt: Date
    var revision: Int64

    init(
        id: UUID = UUID(),
        profileID: UUID? = nil,
        name: String = "Sleep schedule",
        kind: AlarmScheduleKind = .sleep,
        bedtimeHour: Int? = 22,
        bedtimeMinute: Int? = 30,
        wakeHour: Int = 6,
        wakeMinute: Int = 30,
        weekdaysMask: Int = 0b0111_1111,
        oneTimeDate: AlarmLocalDate? = nil,
        bedtimeReminderLeadMinutes: Int? = 15,
        wakeReminderLeadMinutes: Int? = 15,
        finalWakeAlarmEnabled: Bool = true,
        wakeAudio: AlarmAudioSelection? = .defaultBundled,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        revision: Int64 = 1
    ) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.kind = kind
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.weekdaysMask = weekdaysMask
        self.oneTimeDate = oneTimeDate
        self.bedtimeReminderLeadMinutes = bedtimeReminderLeadMinutes
        self.wakeReminderLeadMinutes = wakeReminderLeadMinutes
        self.finalWakeAlarmEnabled = finalWakeAlarmEnabled
        self.wakeAudio = wakeAudio
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
    }

    var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 80,
              validTime(hour: wakeHour, minute: wakeMinute),
              (0 ... 127).contains(weekdaysMask),
              validLead(bedtimeReminderLeadMinutes, options: Self.validReminderLeadOptions),
              validLead(wakeReminderLeadMinutes, options: Self.validWakeAudioLeadOptions)
        else {
            return false
        }

        switch kind {
        case .sleep:
            guard let bedtimeHour,
                  let bedtimeMinute,
                  validTime(hour: bedtimeHour, minute: bedtimeMinute),
                  weekdaysMask != 0,
                  oneTimeDate == nil
            else {
                return false
            }
        case .wakeOnlyRecurring:
            guard weekdaysMask != 0, oneTimeDate == nil else { return false }
        case .wakeOnlyOneTime:
            guard let oneTimeDate, oneTimeDate.isValid, weekdaysMask == 0 else {
                return false
            }
        }

        return true
    }

    var hasBedtime: Bool {
        kind == .sleep
    }

    var hasWakeAudioPlan: Bool {
        wakeReminderLeadMinutes != nil
    }

    var hasFinalWakePlan: Bool {
        finalWakeAlarmEnabled
    }

    var wakeAudioIsUnavailableOnThisDevice: Bool {
        wakeAudio?.availability == .unavailableOnThisDevice
    }

    /// Converts the legacy single-schedule representation without changing
    /// the legacy schedule's UUID semantics (the caller can supply one).
    init(
        legacy schedule: SleepSchedule,
        id: UUID = UUID(),
        profileID: UUID? = nil,
        name: String = "Sleep schedule",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            profileID: profileID,
            name: name,
            kind: .sleep,
            bedtimeHour: schedule.sleepHour,
            bedtimeMinute: schedule.sleepMinute,
            wakeHour: schedule.wakeHour,
            wakeMinute: schedule.wakeMinute,
            weekdaysMask: schedule.weekdaysMask,
            bedtimeReminderLeadMinutes: schedule.reminderLeadMinutes,
            wakeReminderLeadMinutes: schedule.wakeReminderLeadMinutes,
            finalWakeAlarmEnabled: true,
            wakeAudio: .defaultBundled,
            isEnabled: schedule.isEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func validTime(hour: Int, minute: Int) -> Bool {
        (0 ... 23).contains(hour) && (0 ... 59).contains(minute)
    }

    private func validLead(_ value: Int?, options: [Int]) -> Bool {
        value.map { options.contains($0) } ?? true
    }
}

nonisolated enum AlarmEventRole: String, Codable, CaseIterable, Hashable, Sendable {
    case bedtimeReminder = "bedtime_reminder"
    case gentleWake = "gentle_wake"
    case finalWake = "final_wake"
}

nonisolated struct AlarmOccurrenceKey: Codable, Equatable, Hashable, Sendable {
    let date: AlarmLocalDate
    let minuteOfDay: Int
    let role: AlarmEventRole
}

nonisolated struct AlarmScheduleOccurrence: Codable, Equatable, Hashable, Sendable {
    let scheduleID: UUID
    let date: AlarmLocalDate
    let weekday: Int
    let minuteOfDay: Int
    let role: AlarmEventRole

    var key: AlarmOccurrenceKey {
        AlarmOccurrenceKey(date: date, minuteOfDay: minuteOfDay, role: role)
    }
}

nonisolated struct AlarmScheduleCollision: Codable, Equatable, Sendable {
    let first: AlarmScheduleOccurrence
    let second: AlarmScheduleOccurrence

    var date: AlarmLocalDate {
        first.date
    }

    var minuteOfDay: Int {
        first.minuteOfDay
    }
}

nonisolated enum AlarmScheduleValidationError: Error, Codable, Equatable, Sendable {
    case maximumSchedulesExceeded(limit: Int)
    case invalidSchedule(id: UUID)
    case collision(AlarmScheduleCollision)
}

/// Projects all generated alert events into concrete local dates. Recurring
/// schedules are projected across a seven-day window (with one spill day on
/// either side so midnight lead-time changes are never missed).
nonisolated enum AlarmScheduleCollisionValidator {
    static let maximumScheduleCount = AlarmSchedule.maximumCount

    static func project(
        schedule: AlarmSchedule,
        from startDate: AlarmLocalDate = AlarmLocalDate(date: Date()),
        calendar: Calendar = .current
    ) -> [AlarmScheduleOccurrence] {
        guard schedule.isEnabled, schedule.isValid else { return [] }

        switch schedule.kind {
        case .wakeOnlyOneTime:
            guard let date = schedule.oneTimeDate else { return [] }
            return wakeOccurrences(schedule: schedule, date: date, calendar: calendar)
        case .wakeOnlyRecurring:
            return (-1 ... 7).flatMap { offset -> [AlarmScheduleOccurrence] in
                let date = startDate.addingDays(offset, calendar: calendar)
                guard let weekday = calendarWeekday(date, calendar: calendar),
                      includes(schedule.weekdaysMask, weekday)
                else { return [] }
                return wakeOccurrences(schedule: schedule, date: date, calendar: calendar)
            }
        case .sleep:
            guard let bedtimeHour = schedule.bedtimeHour,
                  let bedtimeMinute = schedule.bedtimeMinute
            else { return [] }

            return (-1 ... 7).flatMap { offset -> [AlarmScheduleOccurrence] in
                let bedtimeDate = startDate.addingDays(offset, calendar: calendar)
                guard let weekday = calendarWeekday(bedtimeDate, calendar: calendar),
                      includes(schedule.weekdaysMask, weekday)
                else { return [] }

                var result: [AlarmScheduleOccurrence] = []
                let bedtimeMinuteOfDay = bedtimeHour * 60 + bedtimeMinute
                let wakeMinuteOfDay = schedule.wakeHour * 60 + schedule.wakeMinute

                if let lead = schedule.bedtimeReminderLeadMinutes {
                    let (date, minute) = subtractingMinutes(
                        lead,
                        from: bedtimeDate,
                        minuteOfDay: bedtimeMinuteOfDay,
                        calendar: calendar
                    )
                    result.append(
                        occurrence(
                            scheduleID: schedule.id,
                            date: date,
                            minuteOfDay: minute,
                            role: .bedtimeReminder,
                            calendar: calendar
                        )
                    )
                }

                // A wake at or before bedtime belongs to the following local
                // date, which is the normal overnight sleep case.
                let wakeDate = bedtimeDate.addingDays(
                    wakeMinuteOfDay <= bedtimeMinuteOfDay ? 1 : 0,
                    calendar: calendar
                )
                result.append(
                    contentsOf: wakeOccurrences(
                        schedule: schedule,
                        date: wakeDate,
                        calendar: calendar
                    )
                )
                return result
            }
        }
    }

    static func collisions(
        in schedules: [AlarmSchedule],
        from startDate: AlarmLocalDate = AlarmLocalDate(date: Date()),
        calendar: Calendar = .current
    ) -> [AlarmScheduleCollision] {
        var byInstant: [AlarmLocalDate: [Int: AlarmScheduleOccurrence]] = [:]
        var result: [AlarmScheduleCollision] = []

        for schedule in schedules where schedule.isEnabled && schedule.isValid {
            for occurrence in project(schedule: schedule, from: startDate, calendar: calendar) {
                let existing = byInstant[occurrence.date]?[occurrence.minuteOfDay]
                if let existing {
                    result.append(
                        AlarmScheduleCollision(first: existing, second: occurrence)
                    )
                } else {
                    byInstant[occurrence.date, default: [:]][occurrence.minuteOfDay] = occurrence
                }
            }
        }

        return result
    }

    static func validate(
        _ schedules: [AlarmSchedule],
        from startDate: AlarmLocalDate = AlarmLocalDate(date: Date()),
        calendar: Calendar = .current
    ) throws {
        guard schedules.count <= maximumScheduleCount else {
            throw AlarmScheduleValidationError.maximumSchedulesExceeded(
                limit: maximumScheduleCount
            )
        }
        for schedule in schedules where schedule.isEnabled {
            guard schedule.isValid else {
                throw AlarmScheduleValidationError.invalidSchedule(id: schedule.id)
            }
        }
        if let collision = collisions(in: schedules, from: startDate, calendar: calendar).first {
            throw AlarmScheduleValidationError.collision(collision)
        }
    }

    private static func wakeOccurrences(
        schedule: AlarmSchedule,
        date: AlarmLocalDate,
        calendar: Calendar
    ) -> [AlarmScheduleOccurrence] {
        var result: [AlarmScheduleOccurrence] = []
        let wakeMinuteOfDay = schedule.wakeHour * 60 + schedule.wakeMinute
        if let lead = schedule.wakeReminderLeadMinutes {
            let (gentleDate, gentleMinute) = subtractingMinutes(
                lead,
                from: date,
                minuteOfDay: wakeMinuteOfDay,
                calendar: calendar
            )
            result.append(
                occurrence(
                    scheduleID: schedule.id,
                    date: gentleDate,
                    minuteOfDay: gentleMinute,
                    role: .gentleWake,
                    calendar: calendar
                )
            )
        }
        if schedule.finalWakeAlarmEnabled {
            result.append(
                occurrence(
                    scheduleID: schedule.id,
                    date: date,
                    minuteOfDay: wakeMinuteOfDay,
                    role: .finalWake,
                    calendar: calendar
                )
            )
        }
        return result
    }

    private static func occurrence(
        scheduleID: UUID,
        date: AlarmLocalDate,
        minuteOfDay: Int,
        role: AlarmEventRole,
        calendar: Calendar
    ) -> AlarmScheduleOccurrence {
        AlarmScheduleOccurrence(
            scheduleID: scheduleID,
            date: date,
            weekday: calendarWeekday(date, calendar: calendar) ?? 1,
            minuteOfDay: minuteOfDay,
            role: role
        )
    }

    private static func subtractingMinutes(
        _ value: Int,
        from date: AlarmLocalDate,
        minuteOfDay: Int,
        calendar: Calendar
    ) -> (AlarmLocalDate, Int) {
        let total = minuteOfDay - value
        let dayOffset = Int(floor(Double(total) / Double(24 * 60)))
        let normalized = ((total % (24 * 60)) + (24 * 60)) % (24 * 60)
        return (
            date.addingDays(dayOffset, calendar: calendar),
            normalized
        )
    }

    private static func calendarWeekday(
        _ date: AlarmLocalDate,
        calendar: Calendar
    ) -> Int? {
        guard let foundationDate = date.date(in: calendar) else { return nil }
        return calendar.component(.weekday, from: foundationDate)
    }

    private static func includes(_ mask: Int, _ weekday: Int) -> Bool {
        guard (1 ... 7).contains(weekday) else { return false }
        return mask & (1 << (weekday - 1)) != 0
    }
}

typealias AlarmScheduleValidator = AlarmScheduleCollisionValidator

nonisolated struct SleepSchedule: Codable, Equatable, Sendable {
    static let wakeReminderLeadOptions = [5, 10, 15, 30]

    var sleepHour: Int
    var sleepMinute: Int
    var wakeHour: Int
    var wakeMinute: Int
    var weekdaysMask: Int
    var reminderLeadMinutes: Int
    var isEnabled: Bool
    /// `nil` means the person has turned the wake-up audio alarm off.
    var wakeReminderLeadMinutes: Int?

    init(
        sleepHour: Int,
        sleepMinute: Int,
        wakeHour: Int,
        wakeMinute: Int,
        weekdaysMask: Int,
        reminderLeadMinutes: Int,
        isEnabled: Bool,
        wakeReminderLeadMinutes: Int? = nil
    ) {
        self.sleepHour = sleepHour
        self.sleepMinute = sleepMinute
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.weekdaysMask = weekdaysMask
        self.reminderLeadMinutes = reminderLeadMinutes
        self.isEnabled = isEnabled
        self.wakeReminderLeadMinutes = wakeReminderLeadMinutes
    }

    static let defaultValue = SleepSchedule(
        sleepHour: 22,
        sleepMinute: 30,
        wakeHour: 6,
        wakeMinute: 30,
        weekdaysMask: 0b0111_1111,
        reminderLeadMinutes: 15,
        isEnabled: true,
        wakeReminderLeadMinutes: 15
    )

    var isValid: Bool {
        (0 ... 23).contains(sleepHour)
            && (0 ... 59).contains(sleepMinute)
            && (0 ... 23).contains(wakeHour)
            && (0 ... 59).contains(wakeMinute)
            && (0 ... 127).contains(weekdaysMask)
            && [0, 5, 10, 15, 30, 60].contains(reminderLeadMinutes)
            && (wakeReminderLeadMinutes.map(Self.wakeReminderLeadOptions.contains) ?? true)
    }

    var wakeAlarmIsRequested: Bool {
        wakeReminderLeadMinutes != nil
    }

    var alarmSchedule: AlarmSchedule {
        AlarmSchedule(legacy: self)
    }

    init(_ schedule: AlarmSchedule) {
        sleepHour = schedule.bedtimeHour ?? 0
        sleepMinute = schedule.bedtimeMinute ?? 0
        wakeHour = schedule.wakeHour
        wakeMinute = schedule.wakeMinute
        weekdaysMask = schedule.weekdaysMask
        reminderLeadMinutes = schedule.bedtimeReminderLeadMinutes ?? 0
        isEnabled = schedule.isEnabled
        wakeReminderLeadMinutes = schedule.wakeReminderLeadMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case sleepHour
        case sleepMinute
        case wakeHour
        case wakeMinute
        case weekdaysMask
        case reminderLeadMinutes
        case isEnabled
        case wakeReminderLeadMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sleepHour = try container.decode(Int.self, forKey: .sleepHour)
        sleepMinute = try container.decode(Int.self, forKey: .sleepMinute)
        wakeHour = try container.decode(Int.self, forKey: .wakeHour)
        wakeMinute = try container.decode(Int.self, forKey: .wakeMinute)
        weekdaysMask = try container.decode(Int.self, forKey: .weekdaysMask)
        reminderLeadMinutes = try container.decode(Int.self, forKey: .reminderLeadMinutes)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        wakeReminderLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .wakeReminderLeadMinutes)
    }
}

nonisolated enum ReminderAuthorizationState: String, Codable, Sendable {
    case notDetermined
    case authorized
    case denied
    case provisional
    case unavailable
}

nonisolated enum RecoveryAudioChoice: Equatable, Sendable {
    case personal(PersonalAudioClipMetadata)
    case provided(ProvidedRecoveryAudio)
    case unavailable
}

nonisolated struct ProvidedRecoveryAudio: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let bundledResourceName: String?

    static let approvedCatalog = [
        ProvidedRecoveryAudio(
            id: "grounding-short",
            title: "Grounding audio",
            detail: "A short Sleep Paralysis Companion-provided recovery track.",
            bundledResourceName: nil
        ),
        ProvidedRecoveryAudio(
            id: "wind-down",
            title: "Wind-down audio",
            detail: "A longer Sleep Paralysis Companion-provided sleep preparation track.",
            bundledResourceName: nil
        ),
    ]

    var isBundled: Bool {
        bundledResourceName != nil
    }
}

nonisolated enum GroundingPlaybackState: Equatable, Sendable {
    case idle
    case playing(String)
    case paused(String)
    case visualFallback
    case failed
}

nonisolated struct MorningCheckInForm: Equatable, Sendable {
    var occurrence: EpisodeOccurrence?
    var presentState: PresentState?
    var spcOutcome: SPCOutcome?
    var postEpisodeSupport: PostEpisodeSupport?
    var sleepHelpOutcome: SleepHelpOutcome?

    var canSubmit: Bool {
        occurrence != nil
    }
}

nonisolated enum Phase1ActionError: Error, Equatable, Sendable {
    case authenticationRequired
    case configurationRequired
    case invalidQuestionnaire
    case invalidSchedule
    case permissionDenied
    case audioUnavailable
    case persistenceFailed
    case accountMismatch
    case unsupported
}
