import Foundation

actor LocalOnboardingProfileStore: OnboardingProfilePersisting {
    private let location: LocalStoreLocation
    private let protection: any ProtectedFileApplying
    private var database: LocalDatabase?

    init(
        location: LocalStoreLocation,
        protection: any ProtectedFileApplying = SystemProtectedFileApplicator()
    ) {
        self.location = location
        self.protection = protection
    }

    func loadProfile() async throws -> OnboardingProfile? {
        do {
            return try await databaseInstance().activeProfile().map(Self.onboardingProfile)
        } catch {
            throw Self.safeError(error)
        }
    }

    func createGuestProfileIfAbsent(_ profile: OnboardingProfile) async throws -> OnboardingProfile {
        do {
            let stored = try await databaseInstance().createGuestProfileIfAbsent(profile)
            return Self.onboardingProfile(stored)
        } catch {
            throw Self.safeError(error)
        }
    }

    func markNoticeSeen(version: String, seenAt: Date) async throws -> OnboardingProfile {
        do {
            let stored = try await databaseInstance().markProductNoticeSeen(
                version: version,
                seenAt: seenAt
            )
            return Self.onboardingProfile(stored)
        } catch {
            throw Self.safeError(error)
        }
    }

    private func databaseInstance() throws -> LocalDatabase {
        if let database {
            return database
        }
        let url = try location.databaseURL()
        let opened = try LocalDatabase(path: url.path)
        try protection.applyProtection(to: url, kind: .localDatabase)
        database = opened
        return opened
    }

    private nonisolated static func onboardingProfile(_ profile: LocalProfile) -> OnboardingProfile {
        OnboardingProfile(
            localProfileID: profile.id,
            profileCreatedAt: profile.createdAt,
            productNoticeVersion: profile.productNoticeVersion,
            productNoticeSeenAt: profile.productNoticeSeenAt,
            onboardingCompletedAt: profile.onboardingCompletedAt
        )
    }

    private nonisolated static func safeError(_ error: any Error) -> OnboardingPersistenceError {
        if error is RecordMappingError {
            return .invalidStoredProfile
        }
        return .unavailable
    }
}
