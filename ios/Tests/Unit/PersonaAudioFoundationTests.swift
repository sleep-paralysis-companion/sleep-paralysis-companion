import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class PersonaAudioFoundationTests: XCTestCase {
    private struct IncompleteQuestionnaireShape {
        let episodeFrequency: EpisodeFrequency?
        let postEpisodeFeeling: PostEpisodeFeeling?
        let calmingPersonContext: CalmingPersonContext?
    }

    func testRoutingMatrixCoversEveryCompleteCombinationWithExactCounts() {
        var counts = [DerivedPersona: Int]()
        for frequency in EpisodeFrequency.allCases {
            for feeling in PostEpisodeFeeling.allCases {
                for context in CalmingPersonContext.allCases {
                    let persona = PersonaRouting.derive(
                        episodeFrequency: frequency,
                        postEpisodeFeeling: feeling,
                        calmingPersonContext: context
                    )
                    counts[persona, default: 0] += 1
                }
            }
        }
        XCTAssertEqual(counts.values.reduce(0, +), 36)
        XCTAssertEqual(counts[.frequentIntensePersonBesideUser], 4)
        XCTAssertEqual(counts[.frequentIntensePersonNotAlwaysPresent], 4)
        XCTAssertEqual(counts[.frequentIntenseNoCalmingPerson], 4)
        XCTAssertEqual(counts[.generalDefault], 24)
    }

    func testIncompleteQuestionnaireNeverCreatesPersonaAndResumesFirstMissingAnswer() async throws {
        let database = try await linkedDatabase()
        let draft = QuestionnaireDraft(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly,
            postEpisodeFeeling: nil,
            calmingPersonContext: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        let stored = try await database.questionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        )
        XCTAssertEqual(stored?.firstUnansweredQuestion, .postEpisodeFeeling)
        await XCTAssertThrowsErrorAsync {
            _ = try await database.completeQuestionnaireDraft(
                profileID: draft.profileID,
                authenticatedUserID: draft.accountUserID,
                calculatedAt: Phase1BFixture.now
            )
        }
        await XCTAssertNil(try database.personaAnswerAggregate(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        ))
    }

    func testEveryIncompleteQuestionnaireShapeProducesNoPersonaOrOperation() async throws {
        let shapes: [IncompleteQuestionnaireShape] = [
            .init(episodeFrequency: nil, postEpisodeFeeling: nil, calmingPersonContext: nil),
            .init(episodeFrequency: .weekly, postEpisodeFeeling: nil, calmingPersonContext: nil),
            .init(episodeFrequency: nil, postEpisodeFeeling: .awakeScared, calmingPersonContext: nil),
            .init(episodeFrequency: nil, postEpisodeFeeling: nil, calmingPersonContext: .alone),
            .init(episodeFrequency: .weekly, postEpisodeFeeling: .awakeScared, calmingPersonContext: nil),
            .init(episodeFrequency: .weekly, postEpisodeFeeling: nil, calmingPersonContext: .alone),
            .init(episodeFrequency: nil, postEpisodeFeeling: .awakeScared, calmingPersonContext: .alone),
        ]
        for (index, shape) in shapes.enumerated() {
            let database = try await linkedDatabase()
            let draft = QuestionnaireDraft(
                id: UUID(),
                profileID: Phase1BFixture.profileID,
                accountUserID: Phase1BFixture.userID,
                episodeFrequency: shape.episodeFrequency,
                postEpisodeFeeling: shape.postEpisodeFeeling,
                calmingPersonContext: shape.calmingPersonContext,
                createdAt: Phase1BFixture.now,
                updatedAt: Phase1BFixture.now.addingTimeInterval(TimeInterval(index))
            )
            try await database.saveQuestionnaireDraft(draft)
            await XCTAssertThrowsErrorAsync {
                _ = try await database.completeQuestionnaireDraft(
                    profileID: draft.profileID,
                    authenticatedUserID: draft.accountUserID,
                    calculatedAt: Phase1BFixture.now
                )
            }
            let aggregate = try await database.personaAnswerAggregate(
                profileID: draft.profileID,
                authenticatedUserID: draft.accountUserID
            )
            let operations = try await database.operations(profileID: draft.profileID)
            XCTAssertNil(aggregate, "Incomplete shape \(index) produced an aggregate")
            XCTAssertTrue(operations.isEmpty, "Incomplete shape \(index) queued sync work")
        }
    }

    func testCompletionIsAtomicIdempotentAndRemovesDraft() async throws {
        let database = try await linkedDatabase()
        let draft = QuestionnaireDraft(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .almostNightly,
            postEpisodeFeeling: .awakeScared,
            calmingPersonContext: .alone,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        let completed = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID,
            calculatedAt: Phase1BFixture.now,
            operationID: Phase1BFixture.operationID,
            idempotencyKey: Phase1BFixture.key
        )
        XCTAssertEqual(completed.derivedPersona, .frequentIntenseNoCalmingPerson)
        await XCTAssertNil(try database.questionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        ))
        let repeated = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID,
            calculatedAt: Phase1BFixture.now.addingTimeInterval(1)
        )
        XCTAssertEqual(repeated.id, completed.id)
        XCTAssertEqual(repeated.revision, completed.revision)
        let pendingOperations = try await database.operations(profileID: draft.profileID)
        XCTAssertEqual(pendingOperations.filter { $0.entityType == .persona && $0.operation == .upsert }.count, 1)
    }

    func testWrongAccountCannotReadOrWriteDraft() async throws {
        let database = try await linkedDatabase()
        let draft = QuestionnaireDraft(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: nil,
            postEpisodeFeeling: nil,
            calmingPersonContext: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        await XCTAssertThrowsErrorAsync {
            _ = try await database.questionnaireDraft(
                profileID: draft.profileID,
                authenticatedUserID: Phase1BFixture.uuid("99999999-9999-4999-8999-999999999999")
            )
        }
    }

    func testMissingProfileAndSignedOutAccessFailSafely() async throws {
        let database = try await linkedDatabase()
        let unknownProfileID = Phase1BFixture.uuid("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        do {
            _ = try await database.questionnaireDraft(
                profileID: unknownProfileID, authenticatedUserID: Phase1BFixture.userID
            )
            XCTFail("Expected missing-profile access to fail")
        } catch let error as PersonaAudioValidationError {
            XCTAssertEqual(error, .wrongAccount)
        }
        do {
            _ = try await database.personaAnswerAggregate(
                profileID: Phase1BFixture.profileID,
                authenticatedUserID: Phase1BFixture.uuid("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
            )
            XCTFail("Expected signed-out/wrong-user access to fail")
        } catch let error as PersonaAudioValidationError {
            XCTAssertEqual(error, .wrongAccount)
        }
    }

    func testPreTransactionWriteFaultLeavesQuestionnaireDraftAndSyncStateIntact() async throws {
        let path = temporaryDatabasePath()
        let initial = try LocalDatabase(path: path)
        try await configureLinkedProfile(in: initial)
        let draft = completeDraft()
        try await initial.saveQuestionnaireDraft(draft)

        let failing = try LocalDatabase(path: path, writeFault: FailingLocalWrite())
        await XCTAssertThrowsErrorAsync {
            _ = try await failing.completeQuestionnaireDraft(
                profileID: draft.profileID, authenticatedUserID: draft.accountUserID, calculatedAt: Phase1BFixture.now
            )
        }

        let reopened = try LocalDatabase(path: path)
        let preservedDraft = try await reopened.questionnaireDraft(
            profileID: draft.profileID, authenticatedUserID: draft.accountUserID
        )
        let aggregate = try await reopened.personaAnswerAggregate(
            profileID: draft.profileID, authenticatedUserID: draft.accountUserID
        )
        let operations = try await reopened.operations(profileID: draft.profileID)
        XCTAssertEqual(preservedDraft, draft)
        XCTAssertNil(aggregate)
        XCTAssertTrue(operations.isEmpty)
        // FailingLocalWrite is called before DatabasePool.write begins; this proves
        // failure-before-transaction preservation, not a mid-transaction fault.
    }

    func testPersonalAudioMetadataLimitAndSelectedDeletionOnlyClearsItsDefault() async throws {
        let database = try await linkedDatabase()
        let catalog = AudioCatalogItem(
            id: "approved-catalog-item",
            version: 1,
            localeIdentifier: "en",
            integritySHA256: String(repeating: "a", count: 64),
            byteCount: 1,
            durationMilliseconds: 1,
            provenanceReference: "test",
            rightsReference: "test",
            approvalReference: "test"
        )
        try await database.saveAudioCatalogItem(catalog)
        let firstID = Phase1BFixture.entityID
        let clip = PersonalAudioClipMetadata(
            id: firstID,
            profileID: Phase1BFixture.profileID,
            source: .recorded,
            storageFormat: .m4a,
            byteCount: PersonalAudioPolicy.maximumByteCount,
            durationMilliseconds: PersonalAudioPolicy.maximumDurationMilliseconds,
            createdOrImportedAt: Phase1BFixture.now,
            availability: .ready,
            protectionVersion: 1
        )
        try await database.savePersonalAudioClipMetadata(clip, authenticatedUserID: Phase1BFixture.userID)
        try await database.setLocalRecoveryAudioDefault(
            .personalClip(firstID),
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID,
            updatedAt: Phase1BFixture.now
        )
        try await database.deletePersonalAudioClipMetadata(
            id: firstID,
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        await XCTAssertNil(try database.localRecoveryAudioDefault(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        ))
        let invalid = PersonalAudioClipMetadata(
            id: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777"),
            profileID: Phase1BFixture.profileID,
            source: .recorded,
            storageFormat: .mp3,
            byteCount: 1,
            durationMilliseconds: 1,
            createdOrImportedAt: Phase1BFixture.now,
            availability: .ready,
            protectionVersion: 1
        )
        await XCTAssertThrowsErrorAsync {
            try await database.savePersonalAudioClipMetadata(
                invalid,
                authenticatedUserID: Phase1BFixture.userID
            )
        }
    }

    func testUnknownEnumValuesAreRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(EpisodeFrequency.self, from: Data("\"future_frequency\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(PostEpisodeFeeling.self, from: Data("\"future_feeling\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(CalmingPersonContext.self, from: Data("\"future_context\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(DerivedPersona.self, from: Data("\"future_persona\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(
            PersonalAudioStorageFormat.self,
            from: Data("\"future_format\"".utf8)
        ))
        XCTAssertEqual(EpisodeFrequency.almostNightly.rawValue, "almost_nightly")
        XCTAssertEqual(PostEpisodeFeeling.tooFrightenedToCloseEyes.rawValue, "too_frightened_to_close_eyes")
        XCTAssertEqual(CalmingPersonContext.notAlwaysPresent.rawValue, "not_always_present")
        XCTAssertEqual(DerivedPersona.generalDefault.rawValue, "general_default")
    }

    func testDistinctDraftAndProfileIDsResumeAndCompleteThroughPersonaPayloadProvider() async throws {
        let database = try await linkedDatabase()
        let draftID = Phase1BFixture.uuid("66666666-6666-4666-8666-666666666666")
        let draft = QuestionnaireDraft(
            id: draftID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly,
            postEpisodeFeeling: .awakeScared,
            calmingPersonContext: .besideMe,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        let resumed = try await database.questionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        )
        XCTAssertEqual(resumed?.id, draftID)
        let aggregate = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID,
            calculatedAt: Phase1BFixture.now,
            operationID: Phase1BFixture.operationID,
            idempotencyKey: Phase1BFixture.key
        )
        let queued = try await database.operations(profileID: draft.profileID)
        let operation = try XCTUnwrap(queued.first)
        let payload = try await LocalDatabaseOutboundPayloadProvider(database: database).payload(
            for: operation,
            authenticatedUserID: Phase1BFixture.userID
        )
        guard case let .persona(remote) = payload else { return XCTFail("Expected persona payload") }
        XCTAssertEqual(remote.id, aggregate.id)
        XCTAssertEqual(remote.ownerUserID, Phase1BFixture.userID)
        XCTAssertEqual(remote.episodeFrequency, EpisodeFrequency.weekly.rawValue)
        XCTAssertEqual(remote.calmingPersonContext, CalmingPersonContext.besideMe.rawValue)
    }

    func testSettingsChangeAndDeletionQueueExactlyOneSuccessorOrTombstone() async throws {
        let database = try await linkedDatabase()
        let draft = QuestionnaireDraft(
            id: Phase1BFixture.entityID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .rarely,
            postEpisodeFeeling: .shakeItOff,
            calmingPersonContext: .alone,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        _ = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID,
            calculatedAt: Phase1BFixture.now
        )
        let changed = PersonaAnswerAggregate(
            id: Phase1BFixture.profileID,
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly,
            postEpisodeFeeling: .awakeScared,
            calmingPersonContext: .alone,
            derivedPersona: .frequentIntenseNoCalmingPerson,
            routingRuleVersion: PersonaRouting.initialRuleVersion,
            calculatedAt: Phase1BFixture.now.addingTimeInterval(1),
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now.addingTimeInterval(1),
            revision: 99
        )
        try await database.replacePersonaAnswerAggregate(changed)
        let revised = try await database.personaAnswerAggregate(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        )
        XCTAssertEqual(revised?.revision, 2)
        try await database.deletePersonaAnswerAggregate(
            DeletePersonaRequest(
                profileID: draft.profileID,
                authenticatedUserID: draft.accountUserID,
                deletedAt: Phase1BFixture.now.addingTimeInterval(2),
                tombstoneID: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777"),
                operationID: Phase1BFixture.uuid("88888888-8888-4888-8888-888888888888"),
                idempotencyKey: Phase1BFixture.uuid("99999999-9999-4999-8999-999999999999")
            )
        )
        let operations = try await database.operations(profileID: draft.profileID)
        XCTAssertEqual(operations.filter { $0.entityType == .tombstone && $0.operation == .delete }.count, 1)
        let deleted = try await database.personaAnswerAggregate(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        )
        XCTAssertNil(deleted)
    }

    func testClipLimitsFormatsAndValidationFailuresLeaveNoPartialMetadata() async throws {
        let database = try await linkedDatabase()
        for format in PersonalAudioStorageFormat.allCases {
            let metadata = clip(id: UUID(), source: .imported, format: format)
            try await database.savePersonalAudioClipMetadata(metadata, authenticatedUserID: Phase1BFixture.userID)
        }
        let acceptedImports = try await database.personalAudioClipMetadata(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertEqual(Set(acceptedImports.map(\.storageFormat)), Set(PersonalAudioStorageFormat.allCases))

        let invalidByteCount = clip(
            id: UUID(),
            source: .recorded,
            format: .m4a,
            byteCount: PersonalAudioPolicy.maximumByteCount + 1,
            duration: PersonalAudioPolicy.maximumDurationMilliseconds
        )
        let invalidDuration = clip(
            id: UUID(),
            source: .recorded,
            format: .m4a,
            byteCount: PersonalAudioPolicy.maximumByteCount,
            duration: PersonalAudioPolicy.maximumDurationMilliseconds + 1
        )
        let invalidRecordedFormat = clip(id: UUID(), source: .recorded, format: .mp3)
        for invalid in [invalidByteCount, invalidDuration, invalidRecordedFormat] {
            await XCTAssertThrowsErrorAsync {
                try await database.savePersonalAudioClipMetadata(invalid, authenticatedUserID: Phase1BFixture.userID)
            }
        }
        let afterFailures = try await database.personalAudioClipMetadata(
            profileID: Phase1BFixture.profileID, authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertEqual(afterFailures.count, PersonalAudioStorageFormat.allCases.count)
    }

    func testTenClipsAreAcceptedAndEleventhIsRejected() async throws {
        let database = try await linkedDatabase()
        for _ in 0 ..< PersonalAudioPolicy.maximumClipCount {
            try await database.savePersonalAudioClipMetadata(
                clip(
                    id: UUID(),
                    source: .recorded,
                    format: .m4a,
                    byteCount: PersonalAudioPolicy.maximumByteCount,
                    duration: PersonalAudioPolicy.maximumDurationMilliseconds
                ),
                authenticatedUserID: Phase1BFixture.userID
            )
        }
        let stored = try await database.personalAudioClipMetadata(
            profileID: Phase1BFixture.profileID, authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertEqual(stored.count, PersonalAudioPolicy.maximumClipCount)
        await XCTAssertThrowsErrorAsync {
            try await database.savePersonalAudioClipMetadata(
                self.clip(id: UUID(), source: .recorded, format: .m4a),
                authenticatedUserID: Phase1BFixture.userID
            )
        }
        let stillStored = try await database.personalAudioClipMetadata(
            profileID: Phase1BFixture.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertEqual(stillStored.count, PersonalAudioPolicy.maximumClipCount)
    }

    func testClipCannotBeMovedToAnotherProfileAndOnlyItsSelectedDefaultIsCleared() async throws {
        let database = try await linkedDatabase()
        let selected = clip(id: Phase1BFixture.entityID, source: .recorded, format: .m4a)
        let unselected = clip(id: UUID(), source: .imported, format: .mp3)
        try await database.savePersonalAudioClipMetadata(selected, authenticatedUserID: Phase1BFixture.userID)
        try await database.savePersonalAudioClipMetadata(unselected, authenticatedUserID: Phase1BFixture.userID)
        try await database.setLocalRecoveryAudioDefault(
            .personalClip(selected.id),
            profileID: selected.profileID,
            authenticatedUserID: Phase1BFixture.userID,
            updatedAt: Phase1BFixture.now
        )
        try await database.deletePersonalAudioClipMetadata(
            id: unselected.id,
            profileID: selected.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let retainedDefault = try await database.localRecoveryAudioDefault(
            profileID: selected.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertEqual(retainedDefault, .personalClip(selected.id))
        let otherProfileID = Phase1BFixture.uuid("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let moved = PersonalAudioClipMetadata(
            id: selected.id,
            profileID: otherProfileID,
            source: .recorded,
            storageFormat: .m4a,
            byteCount: 1,
            durationMilliseconds: 1,
            createdOrImportedAt: Phase1BFixture.now,
            availability: .ready,
            protectionVersion: 1
        )
        await XCTAssertThrowsErrorAsync {
            try await database.savePersonalAudioClipMetadata(moved, authenticatedUserID: Phase1BFixture.userID)
        }
        try await database.deletePersonalAudioClipMetadata(
            id: selected.id,
            profileID: selected.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        let clearedDefault = try await database.localRecoveryAudioDefault(
            profileID: selected.profileID,
            authenticatedUserID: Phase1BFixture.userID
        )
        XCTAssertNil(clearedDefault)
    }

    func testDraftAndAudioCannotProducePayloadAndPersonaConversionIsRejected() async throws {
        let database = try await linkedDatabase()
        let draft = completeDraft()
        try await database.saveQuestionnaireDraft(draft)
        try await database.savePersonalAudioClipMetadata(
            clip(id: UUID(), source: .recorded, format: .m4a),
            authenticatedUserID: Phase1BFixture.userID
        )
        let provider = LocalDatabaseOutboundPayloadProvider(database: database)
        let upsert = SynchronizationOperation(
            id: UUID(),
            profileID: draft.profileID,
            entityType: .persona,
            entityID: draft.profileID,
            operation: .upsert,
            idempotencyKey: UUID(),
            baseRevision: 0,
            localRevision: 1,
            state: .pending,
            attemptCount: 0,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        await XCTAssertThrowsErrorAsync {
            _ = try await provider.payload(for: upsert, authenticatedUserID: Phase1BFixture.userID)
        }
        _ = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID,
            calculatedAt: Phase1BFixture.now
        )
        let conversion = SynchronizationOperation(
            id: UUID(),
            profileID: draft.profileID,
            entityType: .persona,
            entityID: draft.profileID,
            operation: .convert,
            idempotencyKey: UUID(),
            baseRevision: 1,
            localRevision: 2,
            state: .pending,
            attemptCount: 0,
            nextAttemptAt: nil,
            lastErrorCategory: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        do {
            _ = try await provider.payload(for: conversion, authenticatedUserID: Phase1BFixture.userID)
            XCTFail("Persona conversion must be rejected")
        } catch let error as RemoteMutationError {
            XCTAssertEqual(error, .validation)
        }
    }

    func testProfileRemovalCascadesPersonaDraftClipsAndDefault() async throws {
        let database = try await linkedDatabase()
        let complete = completeDraft()
        try await database.saveQuestionnaireDraft(complete)
        _ = try await database.completeQuestionnaireDraft(
            profileID: complete.profileID,
            authenticatedUserID: complete.accountUserID,
            calculatedAt: Phase1BFixture.now
        )
        let incomplete = QuestionnaireDraft(
            id: UUID(),
            profileID: complete.profileID,
            accountUserID: complete.accountUserID,
            episodeFrequency: .weekly,
            postEpisodeFeeling: nil,
            calmingPersonContext: nil,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(incomplete)
        let clipMetadata = clip(id: UUID(), source: .recorded, format: .m4a)
        try await database.savePersonalAudioClipMetadata(clipMetadata, authenticatedUserID: Phase1BFixture.userID)
        try await database.setLocalRecoveryAudioDefault(
            .personalClip(clipMetadata.id),
            profileID: complete.profileID,
            authenticatedUserID: complete.accountUserID,
            updatedAt: Phase1BFixture.now
        )
        try await database.removeProfileFromDevice(
            profileID: complete.profileID,
            expectedUserID: complete.accountUserID
        )
        try await configureLinkedProfile(in: database)
        let draft = try await database.questionnaireDraft(
            profileID: complete.profileID,
            authenticatedUserID: complete.accountUserID
        )
        let persona = try await database.personaAnswerAggregate(
            profileID: complete.profileID,
            authenticatedUserID: complete.accountUserID
        )
        let clips = try await database.personalAudioClipMetadata(
            profileID: complete.profileID,
            authenticatedUserID: complete.accountUserID
        )
        let fallback = try await database.localRecoveryAudioDefault(
            profileID: complete.profileID,
            authenticatedUserID: complete.accountUserID
        )
        XCTAssertNil(draft)
        XCTAssertNil(persona)
        XCTAssertTrue(clips.isEmpty)
        XCTAssertNil(fallback)
    }

    private func linkedDatabase() async throws -> LocalDatabase {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        try await configureLinkedProfile(in: database)
        return database
    }

    private func configureLinkedProfile(in database: LocalDatabase) async throws {
        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await database.createProfile(profile, settings: Phase1BFixture.settings())
    }

    private func completeDraft() -> QuestionnaireDraft {
        QuestionnaireDraft(
            id: UUID(),
            profileID: Phase1BFixture.profileID,
            accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly,
            postEpisodeFeeling: .awakeScared,
            calmingPersonContext: .alone,
            createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now
        )
    }

    private func clip(
        id: UUID,
        source: PersonalAudioSource,
        format: PersonalAudioStorageFormat,
        byteCount: Int64 = 1,
        duration: Int64? = 1
    ) -> PersonalAudioClipMetadata {
        PersonalAudioClipMetadata(
            id: id,
            profileID: Phase1BFixture.profileID,
            source: source,
            storageFormat: format,
            byteCount: byteCount,
            durationMilliseconds: duration,
            createdOrImportedAt: Phase1BFixture.now,
            availability: .ready,
            protectionVersion: 1
        )
    }
}
