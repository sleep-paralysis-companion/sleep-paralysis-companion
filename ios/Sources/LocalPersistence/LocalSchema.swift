import Foundation
import GRDB

nonisolated enum LocalSchema {
    static let currentVersion = 4

    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        registerCoreLocalData(on: &migrator)
        registerSyncSecurityFoundation(on: &migrator)
        registerPersonaAndLocalAudio(on: &migrator)
        registerPersonaAudioRepair(on: &migrator)
        return migrator
    }

    private static func registerCoreLocalData(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_core_local_data") { database in
            try database.execute(
                sql: """
                CREATE TABLE spc_schema_metadata (
                    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
                    schema_version INTEGER NOT NULL CHECK (schema_version > 0)
                );
                INSERT INTO spc_schema_metadata (singleton, schema_version) VALUES (1, 1);

                CREATE TABLE local_profiles (
                    id TEXT PRIMARY KEY NOT NULL,
                    createdAt REAL NOT NULL,
                    onboardingCompletedAt REAL,
                    productNoticeVersion TEXT NOT NULL CHECK (length(productNoticeVersion) BETWEEN 1 AND 64),
                    productNoticeSeenAt REAL NOT NULL,
                    ownership TEXT NOT NULL CHECK (
                        ownership IN ('guestLocal', 'accountLinked', 'formerAccountProtected')
                    ),
                    accountUserID TEXT,
                    accountLinkState TEXT NOT NULL CHECK (
                        accountLinkState IN (
                            'localOnly', 'authenticating', 'awaitingMergeChoice', 'converting',
                            'linked', 'conflict', 'authRequired', 'failedRecoverable'
                        )
                    ),
                    CHECK (
                        (ownership = 'guestLocal' AND accountUserID IS NULL)
                        OR ownership <> 'guestLocal'
                    )
                );
                CREATE UNIQUE INDEX local_profiles_single_installation
                    ON local_profiles ((1));

                CREATE TABLE app_settings (
                    profileID TEXT PRIMARY KEY NOT NULL
                        REFERENCES local_profiles(id) ON DELETE CASCADE,
                    preferredGroundingAssetID TEXT,
                    preferredModality TEXT NOT NULL CHECK (
                        preferredModality IN ('audio', 'visual', 'silent')
                    ),
                    hapticsEnabled INTEGER NOT NULL CHECK (hapticsEnabled IN (0, 1)),
                    lastSelectedHistoryPeriod TEXT NOT NULL CHECK (
                        lastSelectedHistoryPeriod IN ('sevenDays', 'thirtyDays', 'all')
                    ),
                    diagnosticsEnabled INTEGER NOT NULL DEFAULT 0
                        CHECK (diagnosticsEnabled IN (0, 1)),
                    updatedAt REAL NOT NULL,
                    revision INTEGER NOT NULL CHECK (revision > 0)
                );

                CREATE TABLE submitted_checkins (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    reportedForLocalDate TEXT NOT NULL CHECK (
                        reportedForLocalDate GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                    ),
                    reportedTimezoneID TEXT NOT NULL CHECK (length(reportedTimezoneID) BETWEEN 1 AND 128),
                    occurrence TEXT NOT NULL CHECK (occurrence IN ('yes', 'no')),
                    perceivedIntensity TEXT CHECK (
                        perceivedIntensity IN ('mild', 'moderate', 'severe', 'extreme')
                    ),
                    presentState TEXT CHECK (
                        presentState IN ('fine_now', 'still_shaken', 'exhausted')
                    ),
                    note TEXT CHECK (note IS NULL OR length(note) BETWEEN 1 AND 500),
                    createdAt REAL NOT NULL,
                    updatedAt REAL NOT NULL CHECK (updatedAt >= createdAt),
                    revision INTEGER NOT NULL CHECK (revision > 0),
                    deletedAt REAL,
                    UNIQUE (profileID, reportedForLocalDate),
                    CHECK (occurrence = 'yes' OR perceivedIntensity IS NULL)
                );
                CREATE INDEX submitted_checkins_profile_active_date
                    ON submitted_checkins(profileID, reportedForLocalDate DESC)
                    WHERE deletedAt IS NULL;

                CREATE TABLE checkin_drafts (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    reportedForLocalDate TEXT,
                    reportedTimezoneID TEXT,
                    occurrence TEXT CHECK (occurrence IN ('yes', 'no')),
                    perceivedIntensity TEXT CHECK (
                        perceivedIntensity IN ('mild', 'moderate', 'severe', 'extreme')
                    ),
                    presentState TEXT CHECK (
                        presentState IN ('fine_now', 'still_shaken', 'exhausted')
                    ),
                    note TEXT CHECK (note IS NULL OR length(note) BETWEEN 1 AND 500),
                    draftUpdatedAt REAL NOT NULL,
                    UNIQUE (profileID, reportedForLocalDate),
                    CHECK (occurrence = 'yes' OR perceivedIntensity IS NULL)
                );
                CREATE INDEX checkin_drafts_expiry ON checkin_drafts(draftUpdatedAt);
                """
            )
        }
    }

    private static func registerSyncSecurityFoundation(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2_sync_security_foundation") { database in
            try database.execute(
                sql: """
                CREATE TABLE alarm_preferences (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    systemAlarmID TEXT,
                    localHour INTEGER NOT NULL CHECK (localHour BETWEEN 0 AND 23),
                    localMinute INTEGER NOT NULL CHECK (localMinute BETWEEN 0 AND 59),
                    weekdaysMask INTEGER NOT NULL CHECK (weekdaysMask BETWEEN 0 AND 127),
                    snoozeMinutes INTEGER CHECK (snoozeMinutes IN (5, 10, 15)),
                    enabledIntent INTEGER NOT NULL CHECK (enabledIntent IN (0, 1)),
                    systemState TEXT NOT NULL CHECK (
                        systemState IN (
                            'notScheduled', 'scheduled', 'denied', 'unsupported',
                            'failed', 'needsAttention'
                        )
                    ),
                    lastScheduleResult TEXT NOT NULL CHECK (
                        lastScheduleResult IN ('none', 'success', 'denied', 'unsupported', 'failed')
                    ),
                    createdAt REAL NOT NULL,
                    updatedAt REAL NOT NULL CHECK (updatedAt >= createdAt),
                    revision INTEGER NOT NULL CHECK (revision > 0)
                );
                CREATE INDEX alarm_preferences_profile ON alarm_preferences(profileID);

                CREATE TABLE audio_catalog (
                    id TEXT PRIMARY KEY NOT NULL CHECK (length(id) BETWEEN 1 AND 128),
                    version INTEGER NOT NULL CHECK (version > 0),
                    localeIdentifier TEXT NOT NULL CHECK (length(localeIdentifier) BETWEEN 1 AND 64),
                    integritySHA256 TEXT NOT NULL CHECK (length(integritySHA256) = 64),
                    byteCount INTEGER NOT NULL CHECK (byteCount >= 0),
                    durationMilliseconds INTEGER NOT NULL CHECK (durationMilliseconds >= 0),
                    provenanceReference TEXT NOT NULL,
                    rightsReference TEXT NOT NULL,
                    approvalReference TEXT NOT NULL
                );

                CREATE TABLE audio_cache (
                    assetID TEXT PRIMARY KEY NOT NULL REFERENCES audio_catalog(id) ON DELETE CASCADE,
                    catalogVersion INTEGER NOT NULL CHECK (catalogVersion > 0),
                    state TEXT NOT NULL CHECK (
                        state IN ('notCached', 'downloading', 'verified', 'invalid', 'revoked')
                    ),
                    relativeFileName TEXT,
                    verifiedAt REAL,
                    byteCount INTEGER NOT NULL CHECK (byteCount >= 0)
                );

                CREATE TABLE account_bindings (
                    profileID TEXT PRIMARY KEY NOT NULL
                        REFERENCES local_profiles(id) ON DELETE CASCADE,
                    userID TEXT NOT NULL UNIQUE,
                    provider TEXT NOT NULL CHECK (provider IN ('apple', 'google')),
                    maskedIdentifier TEXT,
                    linkedAt REAL NOT NULL,
                    sessionExpiresAt REAL NOT NULL,
                    requiresReauthentication INTEGER NOT NULL
                        CHECK (requiresReauthentication IN (0, 1))
                );

                CREATE TABLE sync_operations (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    entityType TEXT NOT NULL CHECK (
                        entityType IN ('profile', 'settings', 'alarm', 'checkIn', 'tombstone')
                    ),
                    entityID TEXT NOT NULL,
                    operation TEXT NOT NULL CHECK (operation IN ('upsert', 'delete', 'convert')),
                    idempotencyKey TEXT NOT NULL UNIQUE,
                    baseRevision INTEGER NOT NULL CHECK (baseRevision >= 0),
                    localRevision INTEGER NOT NULL CHECK (localRevision > 0),
                    state TEXT NOT NULL CHECK (
                        state IN (
                            'pending', 'syncing', 'synced', 'conflicted',
                            'failedRecoverable', 'authRequired', 'deleted'
                        )
                    ),
                    attemptCount INTEGER NOT NULL CHECK (attemptCount >= 0),
                    nextAttemptAt REAL,
                    lastErrorCategory TEXT CHECK (
                        lastErrorCategory IN (
                            'network', 'backendUnavailable', 'authentication',
                            'authorization', 'validation', 'conflict', 'cancelled'
                        )
                    ),
                    createdAt REAL NOT NULL,
                    updatedAt REAL NOT NULL,
                    UNIQUE (profileID, entityType, entityID, operation, localRevision)
                );
                CREATE INDEX sync_operations_ready
                    ON sync_operations(profileID, state, nextAttemptAt, createdAt);
                CREATE UNIQUE INDEX sync_operations_one_inflight
                    ON sync_operations(profileID, entityType, entityID)
                    WHERE state = 'syncing';

                CREATE TABLE entity_revisions (
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    entityType TEXT NOT NULL,
                    entityID TEXT NOT NULL,
                    localRevision INTEGER NOT NULL CHECK (localRevision > 0),
                    acknowledgedRemoteRevision INTEGER,
                    lastRemoteMutationID TEXT,
                    PRIMARY KEY (profileID, entityType, entityID)
                );

                CREATE TABLE deletion_tombstones (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    entityType TEXT NOT NULL,
                    entityID TEXT NOT NULL,
                    deletedRevision INTEGER NOT NULL CHECK (deletedRevision > 0),
                    deletedAt REAL NOT NULL,
                    acknowledgedAt REAL,
                    purgeAfter REAL NOT NULL,
                    UNIQUE (profileID, entityType, entityID),
                    CHECK (acknowledgedAt IS NULL OR acknowledgedAt >= deletedAt),
                    CHECK (purgeAfter >= COALESCE(acknowledgedAt, deletedAt))
                );
                CREATE INDEX deletion_tombstones_retention
                    ON deletion_tombstones(acknowledgedAt, purgeAfter);

                CREATE TABLE policy_notices (
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    noticeKind TEXT NOT NULL,
                    version TEXT NOT NULL,
                    seenAt REAL NOT NULL,
                    PRIMARY KEY (profileID, noticeKind)
                );

                CREATE TABLE export_metadata (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    generatedAt REAL NOT NULL,
                    expiresAt REAL NOT NULL CHECK (expiresAt > generatedAt),
                    scope TEXT NOT NULL CHECK (
                        scope IN ('localOnly', 'lastSyncedLocalSnapshot', 'serverReconciled')
                    ),
                    manifestVersion INTEGER NOT NULL CHECK (manifestVersion > 0)
                );
                CREATE INDEX export_metadata_expiry ON export_metadata(expiresAt);

                CREATE TABLE conversion_checkpoints (
                    conversionID TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL UNIQUE REFERENCES local_profiles(id) ON DELETE CASCADE,
                    expectedUserID TEXT NOT NULL,
                    state TEXT NOT NULL CHECK (
                        state IN (
                            'authenticating', 'awaitingMergeChoice', 'converting',
                            'linked', 'conflict', 'authRequired', 'failedRecoverable'
                        )
                    ),
                    mergeChoice TEXT CHECK (
                        mergeChoice IN ('devicePreferences', 'accountPreferences', 'cancel')
                    ),
                    startedAt REAL NOT NULL,
                    updatedAt REAL NOT NULL
                );

                UPDATE spc_schema_metadata SET schema_version = 2 WHERE singleton = 1;
                """
            )
        }
    }

    private static func registerPersonaAndLocalAudio(on migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v3_persona_and_local_personal_audio") { database in
            try database.execute(
                sql: """
                ALTER TABLE sync_operations RENAME TO sync_operations_v2;
                CREATE TABLE sync_operations (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    entityType TEXT NOT NULL CHECK (
                        entityType IN ('profile', 'settings', 'alarm', 'checkIn', 'persona', 'tombstone')
                    ),
                    entityID TEXT NOT NULL,
                    operation TEXT NOT NULL CHECK (operation IN ('upsert', 'delete', 'convert')),
                    idempotencyKey TEXT NOT NULL UNIQUE,
                    baseRevision INTEGER NOT NULL CHECK (baseRevision >= 0),
                    localRevision INTEGER NOT NULL CHECK (localRevision > 0),
                    state TEXT NOT NULL CHECK (
                        state IN (
                            'pending', 'syncing', 'synced', 'conflicted',
                            'failedRecoverable', 'authRequired', 'deleted'
                        )
                    ),
                    attemptCount INTEGER NOT NULL CHECK (attemptCount >= 0),
                    nextAttemptAt REAL,
                    lastErrorCategory TEXT CHECK (
                        lastErrorCategory IN (
                            'network', 'backendUnavailable', 'authentication',
                            'authorization', 'validation', 'conflict', 'cancelled'
                        )
                    ),
                    createdAt REAL NOT NULL,
                    updatedAt REAL NOT NULL,
                    UNIQUE (profileID, entityType, entityID, operation, localRevision)
                );
                INSERT INTO sync_operations SELECT * FROM sync_operations_v2;
                DROP TABLE sync_operations_v2;
                CREATE INDEX sync_operations_ready
                    ON sync_operations(profileID, state, nextAttemptAt, createdAt);
                CREATE UNIQUE INDEX sync_operations_one_inflight
                    ON sync_operations(profileID, entityType, entityID)
                    WHERE state = 'syncing';

                CREATE TABLE questionnaire_drafts (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL UNIQUE REFERENCES local_profiles(id) ON DELETE CASCADE,
                    accountUserID TEXT NOT NULL,
                    episodeFrequency TEXT CHECK (
                        episodeFrequency IN ('rarely', 'monthly', 'weekly', 'almost_nightly')
                    ),
                    postEpisodeFeeling TEXT CHECK (
                        postEpisodeFeeling IN (
                            'shake_it_off', 'awake_scared', 'too_frightened_to_close_eyes'
                        )
                    ),
                    calmingPersonContext TEXT CHECK (
                        calmingPersonContext IN ('beside_me', 'not_always_present', 'alone')
                    ),
                    createdAt REAL NOT NULL,
                    updatedAt REAL NOT NULL CHECK (updatedAt >= createdAt)
                );
                CREATE INDEX questionnaire_drafts_account_profile
                    ON questionnaire_drafts(accountUserID, profileID);

                CREATE TABLE persona_answer_aggregates (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL UNIQUE REFERENCES local_profiles(id) ON DELETE CASCADE,
                    accountUserID TEXT NOT NULL,
                    episodeFrequency TEXT NOT NULL CHECK (
                        episodeFrequency IN ('rarely', 'monthly', 'weekly', 'almost_nightly')
                    ),
                    postEpisodeFeeling TEXT NOT NULL CHECK (
                        postEpisodeFeeling IN (
                            'shake_it_off', 'awake_scared', 'too_frightened_to_close_eyes'
                        )
                    ),
                    calmingPersonContext TEXT NOT NULL CHECK (
                        calmingPersonContext IN ('beside_me', 'not_always_present', 'alone')
                    ),
                    derivedPersona TEXT NOT NULL CHECK (
                        derivedPersona IN (
                            'frequent_intense_person_not_always_present',
                            'frequent_intense_person_beside_user',
                            'frequent_intense_no_calming_person', 'general_default'
                        )
                    ),
                    routingRuleVersion TEXT NOT NULL CHECK (length(routingRuleVersion) BETWEEN 1 AND 64),
                    calculatedAt REAL NOT NULL,
                    createdAt REAL NOT NULL,
                    updatedAt REAL NOT NULL CHECK (updatedAt >= createdAt),
                    revision INTEGER NOT NULL CHECK (revision > 0)
                );
                CREATE INDEX persona_answer_aggregates_account_profile
                    ON persona_answer_aggregates(accountUserID, profileID);

                CREATE TABLE personal_audio_clip_metadata (
                    id TEXT PRIMARY KEY NOT NULL,
                    profileID TEXT NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    source TEXT NOT NULL CHECK (source IN ('recorded', 'imported')),
                    storageFormat TEXT NOT NULL CHECK (storageFormat IN ('m4a', 'mp3', 'wav', 'aiff', 'caf')),
                    byteCount INTEGER NOT NULL CHECK (byteCount BETWEEN 0 AND 26214400),
                    durationMilliseconds INTEGER CHECK (durationMilliseconds BETWEEN 0 AND 180000),
                    createdOrImportedAt REAL NOT NULL,
                    availability TEXT NOT NULL CHECK (availability IN ('ready', 'unavailable', 'corrupt')),
                    protectionVersion INTEGER NOT NULL CHECK (protectionVersion > 0),
                    CHECK (source <> 'recorded' OR storageFormat = 'm4a')
                );
                CREATE INDEX personal_audio_clip_metadata_profile_created
                    ON personal_audio_clip_metadata(profileID, createdOrImportedAt);

                CREATE TABLE local_recovery_audio_defaults (
                    profileID TEXT PRIMARY KEY NOT NULL REFERENCES local_profiles(id) ON DELETE CASCADE,
                    personalClipID TEXT REFERENCES personal_audio_clip_metadata(id) ON DELETE CASCADE,
                    catalogItemID TEXT REFERENCES audio_catalog(id),
                    updatedAt REAL NOT NULL,
                    CHECK (
                        (personalClipID IS NOT NULL AND catalogItemID IS NULL)
                        OR (personalClipID IS NULL AND catalogItemID IS NOT NULL)
                    )
                );

                UPDATE spc_schema_metadata SET schema_version = 3 WHERE singleton = 1;
                """
            )
        }
    }

    private static func registerPersonaAudioRepair(on migrator: inout DatabaseMigrator) {
        // v3 shipped the intended two-identity shape (an opaque draft id plus a
        // profile-scoped current-draft constraint), but its first consumer used
        // the profile id as if it were the primary key.  Keep the released v3
        // migration immutable and make the ownership/index contract explicit.
        migrator.registerMigration("v4_persona_audio_identity_and_queue_repair") { database in
            try database.execute(sql: """
            CREATE UNIQUE INDEX IF NOT EXISTS questionnaire_drafts_profile_current
                ON questionnaire_drafts(profileID);
            CREATE INDEX IF NOT EXISTS questionnaire_drafts_profile_account_current
                ON questionnaire_drafts(profileID, accountUserID);
            CREATE INDEX IF NOT EXISTS persona_answer_aggregates_profile_account_current
                ON persona_answer_aggregates(profileID, accountUserID);

            CREATE TRIGGER questionnaire_drafts_account_matches_profile_insert
            BEFORE INSERT ON questionnaire_drafts
            WHEN NOT EXISTS (
                SELECT 1 FROM local_profiles
                WHERE id = NEW.profileID AND accountUserID = NEW.accountUserID
            )
            BEGIN
                SELECT RAISE(ABORT, 'questionnaire draft account mismatch');
            END;
            CREATE TRIGGER questionnaire_drafts_account_matches_profile_update
            BEFORE UPDATE OF profileID, accountUserID ON questionnaire_drafts
            WHEN NOT EXISTS (
                SELECT 1 FROM local_profiles
                WHERE id = NEW.profileID AND accountUserID = NEW.accountUserID
            )
            BEGIN
                SELECT RAISE(ABORT, 'questionnaire draft account mismatch');
            END;

            UPDATE spc_schema_metadata SET schema_version = 4 WHERE singleton = 1;
            """)
        }
    }
}

nonisolated enum LocalDatabaseError: Error, Equatable, Sendable {
    case unsupportedNewerSchema(found: Int, supported: Int)
    case corruptOrUnreadable
    case migrationFailed
    case writeFailed
    case constraintViolation
}
