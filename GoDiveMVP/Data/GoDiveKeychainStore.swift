import Foundation
import Security

/// Small Keychain wrapper for account session identifiers (Phase 1 OWASP).
enum GoDiveKeychainStore: Sendable {
    nonisolated static let service = "PrimoSoftware.GoDiveMVP"

    enum Account: String, Sendable {
        case currentProfileID = "account.currentProfileID"
        case lastAppleUserIdentifier = "account.lastAppleUserIdentifier"
        case lastProfileID = "account.lastProfileID"
        case lastDisplayName = "account.lastDisplayName"
        case firebaseUID = "account.firebaseUID"
    }

    /// Device-local; available after first unlock (launch restore without prompting).
    nonisolated static let accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    /// When non-`nil`, reads/writes use this dictionary instead of the system Keychain (unit tests).
    nonisolated(unsafe) static var testingStore: [String: String]?

    @discardableResult
    nonisolated static func setString(_ value: String, account: Account) -> Bool {
        if testingStore != nil {
            testingStore?[account.rawValue] = value
            return true
        }
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = accessible
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    nonisolated static func string(for account: Account) -> String? {
        if let testingStore {
            let value = testingStore[account.rawValue]
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    @discardableResult
    nonisolated static func remove(_ account: Account) -> Bool {
        if testingStore != nil {
            testingStore?[account.rawValue] = nil
            return true
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
