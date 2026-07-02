//
//  IdentityStore.swift
//  Singularity
//

import Foundation
import Security
import os

/// Persists the `IdentityRecord` (brief §12.1 / T-P7-02). The protocol is
/// injectable so the Account UI can be unit-tested with an in-memory store
/// instead of the real Keychain (which needs signing/entitlements).
protocol IdentityStore: Sendable {
    func read() -> IdentityRecord?
    func write(_ record: IdentityRecord)
    func clear()
}

/// Keychain-backed store. Stored at `service = "<bundle-id>.identity"`,
/// `account = "appleID"`, accessible after first unlock, this device only.
struct KeychainIdentityStore: IdentityStore {
    private let service: String
    private let account = "appleID"
    private let logger = Logger(subsystem: "com.reuhenbhalod.Singularity", category: "identity")

    init(service: String = "com.reuhenbhalod.Singularity.identity") {
        self.service = service
    }

    func read() -> IdentityRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(IdentityRecord.self, from: data)
    }

    func write(_ record: IdentityRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        clear()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("keychain write failed status=\(status, privacy: .public)")
        }
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// In-memory store for tests and previews.
final class InMemoryIdentityStore: IdentityStore, @unchecked Sendable {
    private var record: IdentityRecord?
    init(_ record: IdentityRecord? = nil) { self.record = record }
    func read() -> IdentityRecord? { record }
    func write(_ record: IdentityRecord) { self.record = record }
    func clear() { record = nil }
}
