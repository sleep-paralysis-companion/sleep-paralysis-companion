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
            calculatedAt: Phase1BFixture.now
        )
        XCTAssertEqual(completed.derivedPersona, .frequentIntenseNoCalmingPerson)
        XCTAssertNil(try await database.questionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID
        ))
        try await database.saveQuestionnaireDraft(draft)
        let repeated = try await database.completeQuestionnaireDraft(
            profileID: draft.profileID,
            authenticatedUserID: draft.accountUserID,
            calculatedAt: Phase1BFixture.now.addingTimeInterval(1)
        )
        XCTAssertEqual(repeated.id, completed.id)
        XCTAssertEqual(repeated.revision, completed.revision + 1)
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
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                EpisodeFrequency.self,
                from: Data("\"future_frequency\"".utf8)
            )
        )
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
