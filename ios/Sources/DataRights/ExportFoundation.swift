import Foundation

nonisolated struct LocalExportSnapshot: Sendable {
    let appVersion: String
    let profileCreatedAt: Date
    let policyVersions: [String: String]
    let settings: AppSettings
    let alarm: AlarmPreference?
    let checkIns: [SubmittedCheckIn]
    /// Deliberately redacted export projection, never a persistence row.
    let persona: PersonaExport?
    let scope: ExportScope
}

nonisolated struct PersonaExport: Codable, Equatable, Sendable {
    let episodeFrequency: EpisodeFrequency
    let postEpisodeFeeling: PostEpisodeFeeling
    let calmingPersonContext: CalmingPersonContext
    let derivedPersona: DerivedPersona
    let routingRuleVersion: String
    let calculatedAt: Date

    enum CodingKeys: String, CodingKey {
        case episodeFrequency = "episode_frequency"
        case postEpisodeFeeling = "post_episode_feeling"
        case calmingPersonContext = "calming_person_context"
        case derivedPersona = "derived_persona"
        case routingRuleVersion = "routing_rule_version"
        case calculatedAt = "calculated_at"
    }

    init(_ aggregate: PersonaAnswerAggregate) {
        episodeFrequency = aggregate.episodeFrequency
        postEpisodeFeeling = aggregate.postEpisodeFeeling
        calmingPersonContext = aggregate.calmingPersonContext
        derivedPersona = aggregate.derivedPersona
        routingRuleVersion = aggregate.routingRuleVersion
        calculatedAt = aggregate.calculatedAt
    }
}

nonisolated struct ExportArtifact: Equatable, Sendable {
    let archiveURL: URL
    let metadata: ExportMetadata
    let includedFileNames: [String]
}

nonisolated enum ExportError: Error, Equatable, Sendable {
    case temporaryDirectoryUnavailable
    case encodingFailed
    case protectionFailed
    case cleanupFailed
}

nonisolated struct LocalExportService: Sendable {
    private let clock: any Phase1BClock
    private let identifier: any IdentifierGenerating
    private let protection: any ProtectedFileApplying

    init(
        clock: any Phase1BClock,
        identifier: any IdentifierGenerating,
        protection: any ProtectedFileApplying
    ) {
        self.clock = clock
        self.identifier = identifier
        self.protection = protection
    }

    func create(
        snapshot: LocalExportSnapshot,
        profileID: UUID,
        in directory: URL
    ) throws -> ExportArtifact {
        let generatedAt = clock.now()
        let exportID = identifier.next()
        let metadata = ExportMetadata(
            id: exportID,
            profileID: profileID,
            generatedAt: generatedAt,
            expiresAt: generatedAt.addingTimeInterval(86400),
            scope: snapshot.scope,
            manifestVersion: 1
        )

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try protection.applyProtection(to: directory, kind: .sensitiveTemporaryExport)
            let files = try encodedFiles(snapshot: snapshot, metadata: metadata)
            let archiveURL = directory.appendingPathComponent(
                "spc-export-\(exportID.uuidString.lowercased()).zip"
            )
            try DeterministicZIP.make(files: files).write(to: archiveURL, options: .atomic)
            try protection.applyProtection(to: archiveURL, kind: .sensitiveTemporaryExport)
            return ExportArtifact(
                archiveURL: archiveURL,
                metadata: metadata,
                includedFileNames: files.map(\.name)
            )
        } catch let error as ExportError {
            throw error
        } catch {
            throw ExportError.encodingFailed
        }
    }

    func cleanupExpired(
        in directory: URL,
        now: Date,
        maximumEntries: Int = 64
    ) throws {
        do {
            guard FileManager.default.fileExists(atPath: directory.path) else { return }
            let entries = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            for entry in entries
                .filter({ $0.pathExtension == "zip" })
                .prefix(max(0, maximumEntries))
            {
                let values = try entry.resourceValues(forKeys: [.contentModificationDateKey])
                if let modified = values.contentModificationDate,
                   now.timeIntervalSince(modified) >= 86400
                {
                    try FileManager.default.removeItem(at: entry)
                }
            }
        } catch {
            throw ExportError.cleanupFailed
        }
    }

    func remove(_ artifactURL: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: artifactURL.path) {
                try FileManager.default.removeItem(at: artifactURL)
            }
        } catch {
            throw ExportError.cleanupFailed
        }
    }

    private func encodedFiles(
        snapshot: LocalExportSnapshot,
        metadata: ExportMetadata
    ) throws -> [(name: String, data: Data)] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let settingsData = try encoder.encode(snapshot.settings)
        let alarmData = try encoder.encode(snapshot.alarm)
        let visibleCheckIns = snapshot.checkIns.filter { $0.deletedAt == nil }
        let checkInsData = try encoder.encode(visibleCheckIns.map(CheckInExport.init))
        let checkInsCSV = Data(csv(checkIns: visibleCheckIns).utf8)

        var provisional: [(String, Data)] = [
            ("settings.json", settingsData),
            ("alarm.json", alarmData),
            ("checkins.json", checkInsData),
            ("checkins.csv", checkInsCSV),
        ]
        if let persona = snapshot.persona {
            try provisional.append(("persona.json", encoder.encode(persona)))
        }
        let manifest = ExportManifest(
            exportVersion: metadata.manifestVersion,
            appVersion: snapshot.appVersion,
            generatedAt: metadata.generatedAt,
            profileCreatedAt: snapshot.profileCreatedAt,
            policyVersions: snapshot.policyVersions,
            scope: snapshot.scope,
            files: provisional.map {
                ExportManifest.FileEntry(
                    name: $0.0,
                    sha256: SHA256Digest.hex($0.1)
                )
            }
        )
        let manifestData = try encoder.encode(manifest)
        return [("manifest.json", manifestData)] + provisional
    }

    private func csv(checkIns: [SubmittedCheckIn]) -> String {
        let header = "reported_for_local_date,reported_timezone_id,occurrence,perceived_intensity,present_state,note"
        let rows = checkIns.map {
            [
                $0.reportedForLocalDate,
                $0.reportedTimezoneID,
                $0.occurrence.rawValue,
                $0.perceivedIntensity?.rawValue ?? "",
                $0.presentState?.rawValue ?? "",
                $0.note ?? "",
            ].map(csvEscape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }

    private func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

/// The newly added morning-flow answers remain local until a separate export
/// decision is approved. Keep the established export contract unchanged.
private nonisolated struct CheckInExport: Codable {
    let id: UUID
    let profileID: UUID
    let reportedForLocalDate: String
    let reportedTimezoneID: String
    let occurrence: EpisodeOccurrence
    let perceivedIntensity: PerceivedIntensity?
    let presentState: PresentState?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    let revision: Int64
    let deletedAt: Date?

    init(_ value: SubmittedCheckIn) {
        id = value.id
        profileID = value.profileID
        reportedForLocalDate = value.reportedForLocalDate
        reportedTimezoneID = value.reportedTimezoneID
        occurrence = value.occurrence
        perceivedIntensity = value.perceivedIntensity
        presentState = value.presentState
        note = value.note
        createdAt = value.createdAt
        updatedAt = value.updatedAt
        revision = value.revision
        deletedAt = value.deletedAt
    }
}

private nonisolated struct ExportManifest: Codable {
    struct FileEntry: Codable {
        let name: String
        let sha256: String
    }

    let exportVersion: Int
    let appVersion: String
    let generatedAt: Date
    let profileCreatedAt: Date
    let policyVersions: [String: String]
    let scope: ExportScope
    let files: [FileEntry]
}
