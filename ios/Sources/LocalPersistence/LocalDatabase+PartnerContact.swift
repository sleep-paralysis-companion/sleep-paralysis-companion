import Foundation

extension LocalDatabase {
    func partnerContact(profileID: UUID) throws -> PartnerContact? {
        try pool.read { database in
            try PartnerContactRecord.fetchOne(database, key: profileID.uuidString)?.domainValue()
        }
    }

    func savePartnerContact(
        _ contact: PartnerContact,
        profileID: UUID,
        authenticatedUserID: UUID
    ) throws {
        guard let profile = try profile(id: profileID),
              profile.accountUserID == authenticatedUserID
        else {
            throw AuthenticationError.wrongAccount
        }
        try write { database in
            try PartnerContactRecord(
                contact,
                profileID: profileID,
                updatedAt: Date()
            ).save(database)
        }
    }

    func deletePartnerContact(profileID: UUID, authenticatedUserID: UUID) throws {
        guard let profile = try profile(id: profileID),
              profile.accountUserID == authenticatedUserID
        else {
            throw AuthenticationError.wrongAccount
        }
        try write { database in
            try PartnerContactRecord.deleteOne(database, key: profileID.uuidString)
        }
    }
}
