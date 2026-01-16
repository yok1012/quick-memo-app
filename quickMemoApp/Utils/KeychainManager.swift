import Foundation
import Security

/// APIキーをKeychainに安全に保存・取得するマネージャー
class KeychainManager {

    // MARK: - API Provider

    enum APIProvider: String {
        case gemini = "com.quickmemo.api.gemini"
        case claude = "com.quickmemo.api.claude"
        case openai = "com.quickmemo.api.openai"
    }

    // MARK: - Error Types

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case invalidData
        case notFound

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain. Status: \(status)"
            case .loadFailed(let status):
                return "Failed to load from Keychain. Status: \(status)"
            case .deleteFailed(let status):
                return "Failed to delete from Keychain. Status: \(status)"
            case .invalidData:
                return "Invalid data format"
            case .notFound:
                return "API key not found"
            }
        }
    }

    // MARK: - Public Methods

    /// APIキーをKeychainに保存
    /// - Parameters:
    ///   - apiKey: 保存するAPIキー
    ///   - provider: APIプロバイダー
    /// - Throws: KeychainError
    static func save(apiKey: String, for provider: APIProvider) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // 既存のキーを削除（更新の場合）
        try? delete(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }

        print("✅ API key saved for \(provider.rawValue)")
    }

    /// KeychainからAPIキーを取得
    /// - Parameter provider: APIプロバイダー
    /// - Returns: APIキー文字列、存在しない場合はnil
    static func get(for provider: APIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }

    /// KeychainからAPIキーを削除
    /// - Parameter provider: APIプロバイダー
    /// - Throws: KeychainError
    static func delete(for provider: APIProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        // キーが存在しない場合はエラーとしない
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }

        print("🗑️ API key deleted for \(provider.rawValue)")
    }

    /// 指定されたプロバイダーのAPIキーが存在するか確認
    /// - Parameter provider: APIプロバイダー
    /// - Returns: 存在する場合true
    static func exists(for provider: APIProvider) -> Bool {
        return get(for: provider) != nil
    }

    /// すべてのAPIキーを削除（デバッグ・リセット用）
    static func deleteAll() {
        try? delete(for: .gemini)
        try? delete(for: .claude)
        try? delete(for: .openai)
        print("🗑️ All API keys deleted")
    }
}
