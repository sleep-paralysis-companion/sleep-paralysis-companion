import Foundation
@testable import SleepParalysisCompanion
import XCTest

final class PersonaAudioFoundationTests: XCTestCase {
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
        XCTAssertNil(try await database.personaAnswerAggregate(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        ))
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
        XCTAssertNil(try await database.questionnaireDraft(
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
        XCTAssertNil(try await database.localRecoveryAudioDefault(
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
        for value in ["future_frequency", "future_feeling", "future_context", "future_persona"] {
            XCTAssertThrowsError(try JSONDecoder().decode(EpisodeFrequency.self, from: Data("\"\(value)\"".utf8)))
        }
        XCTAssertEqual(EpisodeFrequency.almostNightly.rawValue, "almost_nightly")
        XCTAssertEqual(PostEpisodeFeeling.tooFrightenedToCloseEyes.rawValue, "too_frightened_to_close_eyes")
        XCTAssertEqual(CalmingPersonContext.notAlwaysPresent.rawValue, "not_always_present")
        XCTAssertEqual(DerivedPersona.generalDefault.rawValue, "general_default")
    }

    func testDistinctDraftAndProfileIDsResumeAndCompleteThroughPersonaPayloadProvider() async throws {
        let database = try await linkedDatabase()
        let draftID = Phase1BFixture.uuid("66666666-6666-4666-8666-666666666666")
        let draft = QuestionnaireDraft(
            id: draftID, profileID: Phase1BFixture.profileID, accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly, postEpisodeFeeling: .awakeScared, calmingPersonContext: .besideMe,
            createdAt: Phase1BFixture.now, updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        let resumed = try await database.questionnaireDraft(profileID: draft.profileID, authenticatedUserID: draft.accountUserID)
        XCTAssertEqual(resumed?.id, draftID)
        let aggregate = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID, authenticatedUserID: draft.accountUserID, calculatedAt: Phase1BFixture.now,
            operationID: Phase1BFixture.operationID, idempotencyKey: Phase1BFixture.key
        )
        let queued = try await database.operations(profileID: draft.profileID)
        let operation = try XCTUnwrap(queued.first)
        let payload = try await LocalDatabaseOutboundPayloadProvider(database: database).payload(
            for: operation, authenticatedUserID: Phase1BFixture.userID
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
            id: Phase1BFixture.entityID, profileID: Phase1BFixture.profileID, accountUserID: Phase1BFixture.userID,
            episodeFrequency: .rarely, postEpisodeFeeling: .shakeItOff, calmingPersonContext: .alone,
            createdAt: Phase1BFixture.now, updatedAt: Phase1BFixture.now
        )
        try await database.saveQuestionnaireDraft(draft)
        _ = try await database.completeQuestionnaireDraft(profileID: draft.profileID, authenticatedUserID: draft.accountUserID, calculatedAt: Phase1BFixture.now)
        let changed = PersonaAnswerAggregate(
            id: Phase1BFixture.profileID, profileID: Phase1BFixture.profileID, accountUserID: Phase1BFixture.userID,
            episodeFrequency: .weekly, postEpisodeFeeling: .awakeScared, calmingPersonContext: .alone,
            derivedPersona: .frequentIntenseNoCalmingPerson, routingRuleVersion: PersonaRouting.initialRuleVersion,
            calculatedAt: Phase1BFixture.now.addingTimeInterval(1), createdAt: Phase1BFixture.now,
            updatedAt: Phase1BFixture.now.addingTimeInterval(1), revision: 99
        )
        try await database.replacePersonaAnswerAggregate(changed)
        let revised = try await database.personaAnswerAggregate(profileID: draft.profileID, authenticatedUserID: draft.accountUserID)
        XCTAssertEqual(revised?.revision, 2)
        try await database.deletePersonaAnswerAggregate(
            profileID: draft.profileID, authenticatedUserID: draft.accountUserID,
            deletedAt: Phase1BFixture.now.addingTimeInterval(2),
            tombstoneID: Phase1BFixture.uuid("77777777-7777-4777-8777-777777777777"),
            operationID: Phase1BFixture.uuid("88888888-8888-4888-8888-888888888888"),
            idempotencyKey: Phase1BFixture.uuid("99999999-9999-4999-8999-999999999999")
        )
        let operations = try await database.operations(profileID: draft.profileID)
        XCTAssertEqual(operations.filter { $0.entityType == .tombstone && $0.operation == .delete }.count, 1)
        let deleted = try await database.personaAnswerAggregate(profileID: draft.profileID, authenticatedUserID: draft.accountUserID)
        XCTAssertNil(deleted)
    }

    private func linkedDatabase() async throws -> LocalDatabase {
        let database = try LocalDatabase(path: temporaryDatabasePath())
        var profile = Phase1BFixture.profile()
        profile.ownership = .accountLinked
        profile.accountUserID = Phase1BFixture.userID
        profile.accountLinkState = .linked
        try await database.createProfile(profile, settings: Phase1BFixture.settings())
        return database
    }
}
