import Foundation
import Security
import Supabase

/// # Keychain Session Store & Storage Bridge
///
/// This file implements the post-S4 sanctioned storage architecture:
/// 1. `SupabaseKeychainLocalStorage`: Bridges `supabase-swift`'s `AuthLocalStorage` to iOS Keychain,
///    acting as the sole persistent repository for access and refresh tokens at rest.
/// 2. `KeychainSessionStore`: Stores the non-secret `AuthenticationIdentityRecord` used by the app for
///    cold-launch restore decisions, wrong-account validations, and data-rights flows.
/// 3. `SystemKeychainClient`: Hardware-backed Keychain operations enforcing `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
///
/// See `docs/PHASE_SIGN_IN_FLOW.md` Section 4 for the complete storage inventory.
nonisolated protocol KeychainClient: Sendable {
    func read(service: String, account: String) throws -> Data?
    func write(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

nonisolated struct SystemKeychainClient: KeychainClient {
    func read(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AuthenticationError.keychainFailure
        }
        return data
    }

    func write(_ data: Data, service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw AuthenticationError.keychainFailure
        }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
            throw AuthenticationError.keychainFailure
        }
    }

    func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.keychainFailure
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

nonisolated struct SupabaseKeychainLocalStorage: AuthLocalStorage, Sendable {
    private let keychain: any KeychainClient
    private let service: String

    init(
        keychain: any KeychainClient = SystemKeychainClient(),
        service: String
    ) {
        self.keychain = keychain
        self.service = service
    }

    static func service(
        bundleIdentifier: String = "app.sleepcompanion.spc",
        projectRef: String
    ) -> String {
        "\(bundleIdentifier).supabase.auth.\(projectRef)"
    }

    func store(key: String, value: Data) throws {
        do {
            try keychain.write(value, service: service, account: key)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func retrieve(key: String) throws -> Data? {
        do {
            return try keychain.read(service: service, account: key)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func remove(key: String) throws {
        do {
            try keychain.delete(service: service, account: key)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }
}

nonisolated struct KeychainSessionStore: SessionSecretStore {
    private let keychain: any KeychainClient
    private let service: String
    private let identityAccount: String
    private let legacyAccount: String

    init(
        keychain: any KeychainClient,
        service: String = SessionKeychainIdentity.service,
        identityAccount: String = SessionKeychainIdentity.identityAccount,
        legacyAccount: String = SessionKeychainIdentity.legacyAccount
    ) {
        self.keychain = keychain
        self.service = service
        self.identityAccount = identityAccount
        self.legacyAccount = legacyAccount
    }

    func readIdentity() throws -> AuthenticationIdentityRecord? {
        guard let data = try keychain.read(service: service, account: identityAccount) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(AuthenticationIdentityRecord.self, from: data)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func writeIdentity(_ identity: AuthenticationIdentityRecord) throws {
        do {
            let data = try JSONEncoder().encode(identity)
            try keychain.write(data, service: service, account: identityAccount)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func readLegacyMaterial() throws -> AuthenticationSessionMaterial? {
        guard let data = try keychain.read(service: service, account: legacyAccount) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(AuthenticationSessionMaterial.self, from: data)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func deleteLegacyMaterial() throws {
        try keychain.delete(service: service, account: legacyAccount)
    }

    func delete() throws {
        try keychain.delete(service: service, account: identityAccount)
        try keychain.delete(service: service, account: legacyAccount)
    }
}
