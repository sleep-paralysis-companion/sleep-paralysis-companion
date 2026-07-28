import Foundation

nonisolated enum ProductNotice {
    static let currentVersion = "phase-1c-2026-07"
}

nonisolated struct OnboardingProfile: Equatable, Sendable {
    let localProfileID: UUID
    let profileCreatedAt: Date
    let productNoticeVersion: String
    let productNoticeSeenAt: Date
    let onboardingCompletedAt: Date?
}

nonisolated protocol OnboardingProfilePersisting: Sendable {
    func loadProfile() async throws -> OnboardingProfile?
    func createGuestProfileIfAbsent(_ profile: OnboardingProfile) async throws -> OnboardingProfile
    func markNoticeSeen(version: String, seenAt: Date) async throws -> OnboardingProfile
}

nonisolated enum OnboardingPersistenceError: Error, Equatable, Sendable {
    case unavailable
    case invalidStoredProfile
}

nonisolated protocol AppDateProviding: Sendable {
    func now() -> Date
}

nonisolated protocol AppIdentifierProviding: Sendable {
    func makeIdentifier() -> UUID
}

nonisolated struct SystemAppDateProvider: AppDateProviding {
    func now() -> Date {
        Date()
    }
}

nonisolated struct SystemAppIdentifierProvider: AppIdentifierProviding {
    func makeIdentifier() -> UUID {
        UUID()
    }
}
