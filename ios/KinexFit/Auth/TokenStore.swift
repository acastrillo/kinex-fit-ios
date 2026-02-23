import Foundation
import Security

protocol TokenStore {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func setAccessToken(_ token: String?) throws
    func setRefreshToken(_ token: String?) throws
    func clearAll() throws
}

enum TokenStoreError: Error {
    case unexpectedStatus(OSStatus)
}

final class KeychainTokenStore: TokenStore {
    private let service = "com.kinex.fit"
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"
    private let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    var accessToken: String? {
        getToken(account: accessTokenAccount)
    }

    var refreshToken: String? {
        getToken(account: refreshTokenAccount)
    }

    func setAccessToken(_ token: String?) throws {
        try setToken(token, account: accessTokenAccount)
    }

    func setRefreshToken(_ token: String?) throws {
        try setToken(token, account: refreshTokenAccount)
    }

    func clearAll() throws {
        try setAccessToken(nil)
        try setRefreshToken(nil)
    }

    // MARK: - Private Helpers

    private func getToken(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            // Log unexpected keychain status for visibility; keep return nil to avoid crashing
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                NSLog("[KeychainTokenStore] Unexpected keychain status: \(status) - \(message)")
            } else {
                NSLog("[KeychainTokenStore] Unexpected keychain status: \(status)")
            }
            return nil
        }
        guard let data = item as? Data else {
            NSLog("[KeychainTokenStore] SecItemCopyMatching returned non-Data item for account: \(account)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func setToken(_ token: String?, account: String) throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        guard let token else {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw TokenStoreError.unexpectedStatus(status)
            }
            return
        }

        let data = Data(token.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility
            ] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = accessibility
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw TokenStoreError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw TokenStoreError.unexpectedStatus(updateStatus)
        }
    }
}

final class InMemoryTokenStore: TokenStore {
    private var _accessToken: String?
    private var _refreshToken: String?

    var accessToken: String? {
        _accessToken
    }

    var refreshToken: String? {
        _refreshToken
    }

    func setAccessToken(_ token: String?) throws {
        _accessToken = token
    }

    func setRefreshToken(_ token: String?) throws {
        _refreshToken = token
    }

    func clearAll() throws {
        _accessToken = nil
        _refreshToken = nil
    }
}
