import Foundation
import Security

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

nonisolated struct KeychainSessionStore: SessionSecretStore {
    private let keychain: any KeychainClient
    private let service: String
    private let account: String

    init(
        keychain: any KeychainClient,
        service: String = "app.sleepcompanion.spc.auth",
        account: String = "supabase-session"
    ) {
        self.keychain = keychain
        self.service = service
        self.account = account
    }

    func read() throws -> AuthenticationSessionMaterial? {
        guard let data = try keychain.read(service: service, account: account) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(AuthenticationSessionMaterial.self, from: data)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func write(_ session: AuthenticationSessionMaterial) throws {
        do {
            let data = try JSONEncoder().encode(session)
            try keychain.write(data, service: service, account: account)
        } catch {
            throw AuthenticationError.keychainFailure
        }
    }

    func delete() throws {
        try keychain.delete(service: service, account: account)
    }
}
