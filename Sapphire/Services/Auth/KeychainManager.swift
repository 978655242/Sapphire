//
//  KeychainManager.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-07
//

import Foundation
import Security
import LocalAuthentication

class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private let service = "com.shariq.Sapphire.faceid.keychain"

    func save(key: Data, for account: String) -> Bool {
        let status = KeychainStore.setItem(
            service: service,
            account: account,
            data: key,
            accessible: kSecAttrAccessibleAfterFirstUnlock,
            synchronizable: false
        )

        if status != errSecSuccess {
            print("[KeychainManager] failed to save key: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")")
            return false
        }

        return true
    }

    func contains(for account: String) -> Bool {
        // ponytail: startup checks metadata, never decrypts a password or opens a consent prompt.
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: false,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func load(for account: String) -> Data? {
        let (data, status) = KeychainStore.copyData(
            service: service,
            account: account,
            accessible: kSecAttrAccessibleAfterFirstUnlock,
            synchronizable: false
        )

        if data == nil {
            print("[KeychainManager] failed to load key for \(account): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")")
            return nil
        }

        return data
    }

    func delete(for account: String) -> Bool {
        let status = KeychainStore.deleteItem(
            service: service,
            account: account,
            accessible: kSecAttrAccessibleAfterFirstUnlock,
            synchronizable: false
        )
        let success = (status == errSecSuccess || status == errSecItemNotFound)

        if success {
            print("[KeychainManager] successfully deleted key for \(account)")
        } else {
            print("[KeychainManager] failed to delete key for \(account): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")")
        }

        return success
    }
}