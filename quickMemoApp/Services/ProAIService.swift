import Foundation

/// Pro版限定のAPIキー不要AI機能サービス
/// Firebase Cloud Functionsを経由してAI機能を提供
@MainActor
class ProAIService {
    static let shared = ProAIService()

    // MARK: - Configuration

    // TODO: Firebase Functionsデプロイ後、実際のURLに置き換える
    private let baseURL = "https://asia-northeast1-YOUR-PROJECT-ID.cloudfunctions.net"

    // MARK: - Properties

    private var cachedUserId: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// タグ抽出（Pro版専用）
    /// - Parameters:
    ///   - content: メモ本文
    ///   - provider: AIプロバイダー（デフォルト: Gemini）
    /// - Returns: タグ抽出結果
    func extractTags(from content: String, provider: AIProvider = .gemini) async throws -> TagExtractionResult {
        // Pro版チェック
        guard PurchaseManager.shared.isProVersion else {
            throw ProAIError.proVersionRequired
        }

        // ユーザーID取得
        guard let userId = await getUserId() else {
            throw ProAIError.authenticationRequired
        }

        // リクエストボディ
        let requestBody: [String: Any] = [
            "userId": userId,
            "content": content,
            "provider": provider.rawValue
        ]

        // Cloud Functionsにリクエスト
        let response: TagExtractionResponse = try await request(
            endpoint: "/extractTags",
            body: requestBody
        )

        return TagExtractionResult(tags: response.tags)
    }

    /// メモアレンジ（Pro版専用）
    /// - Parameters:
    ///   - content: 元のメモ本文
    ///   - instruction: アレンジ指示
    ///   - provider: AIプロバイダー（デフォルト: Gemini）
    /// - Returns: アレンジされたメモ本文
    func arrangeMemo(content: String, instruction: String, provider: AIProvider = .gemini) async throws -> String {
        // Pro版チェック
        guard PurchaseManager.shared.isProVersion else {
            throw ProAIError.proVersionRequired
        }

        // ユーザーID取得
        guard let userId = await getUserId() else {
            throw ProAIError.authenticationRequired
        }

        // リクエストボディ
        let requestBody: [String: Any] = [
            "userId": userId,
            "content": content,
            "instruction": instruction,
            "provider": provider.rawValue
        ]

        // Cloud Functionsにリクエスト
        let response: MemoArrangeResponse = try await request(
            endpoint: "/arrangeMemo",
            body: requestBody
        )

        return response.arrangedContent
    }

    /// カテゴリー要約（Pro版専用）
    /// - Parameters:
    ///   - memos: メモ本文の配列
    ///   - provider: AIプロバイダー（デフォルト: Gemini）
    /// - Returns: カテゴリー要約結果
    func summarizeCategory(memos: [String], provider: AIProvider = .gemini) async throws -> CategorySummaryResult {
        // Pro版チェック
        guard PurchaseManager.shared.isProVersion else {
            throw ProAIError.proVersionRequired
        }

        // ユーザーID取得
        guard let userId = await getUserId() else {
            throw ProAIError.authenticationRequired
        }

        // リクエストボディ
        let requestBody: [String: Any] = [
            "userId": userId,
            "memos": memos,
            "provider": provider.rawValue
        ]

        // Cloud Functionsにリクエスト
        let response: CategorySummaryResponse = try await request(
            endpoint: "/summarizeCategory",
            body: requestBody
        )

        return CategorySummaryResult(
            summary: response.summary,
            keyPoints: response.keyPoints,
            trends: response.trends,
            totalMemos: memos.count
        )
    }

    /// 使用量取得（Pro版専用）
    /// - Returns: 使用量情報
    func getUsage() async throws -> ProAIUsageResponse {
        // Pro版チェック
        guard PurchaseManager.shared.isProVersion else {
            throw ProAIError.proVersionRequired
        }

        // ユーザーID取得
        guard let userId = await getUserId() else {
            throw ProAIError.authenticationRequired
        }

        // リクエストボディ
        let requestBody: [String: Any] = [
            "userId": userId
        ]

        // Cloud Functionsにリクエスト
        return try await request(
            endpoint: "/getUsage",
            body: requestBody
        )
    }

    // MARK: - Private Methods

    /// Cloud Functionsへのリクエスト実行
    private func request<T: Decodable>(endpoint: String, body: [String: Any]) async throws -> T {
        // URLの構築
        guard let url = URL(string: baseURL + endpoint) else {
            throw ProAIError.invalidURL
        }

        // リクエストの作成
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // ボディのJSON化
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // リクエストの実行
        let (data, response) = try await URLSession.shared.data(for: request)

        // HTTPレスポンスの確認
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProAIError.networkError
        }

        // ステータスコードによるエラーハンドリング
        switch httpResponse.statusCode {
        case 200:
            // 成功
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)

        case 403:
            // Pro版必須
            throw ProAIError.proVersionRequired

        case 429:
            // 使用量制限超過
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ProAIError.usageLimitExceeded(errorResponse.error)
            }
            throw ProAIError.usageLimitExceeded("月間の使用量制限に達しました")

        case 400:
            // 不正なリクエスト
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ProAIError.invalidRequest(errorResponse.error)
            }
            throw ProAIError.invalidRequest("不正なリクエストです")

        case 500...599:
            // サーバーエラー
            throw ProAIError.serverError

        default:
            throw ProAIError.unknown(httpResponse.statusCode)
        }
    }

    /// ユーザーIDを取得（CloudKit User IDまたはデバイスID）
    private func getUserId() async -> String? {
        // キャッシュがあればそれを返す
        if let cached = cachedUserId {
            return cached
        }

        // CloudKit User IDを取得（Pro版ユーザーは通常サインイン済み）
        if let cloudKitUserId = await AuthenticationManager.shared.getCurrentUserId() {
            cachedUserId = cloudKitUserId
            return cloudKitUserId
        }

        // フォールバック: デバイス固有IDを生成・取得
        if let deviceId = getDeviceId() {
            cachedUserId = deviceId
            return deviceId
        }

        return nil
    }

    /// デバイス固有IDを取得（なければ生成）
    private func getDeviceId() -> String? {
        let key = "pro_ai_device_id"

        // UserDefaultsから取得
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }

        // 新規生成
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}

// MARK: - Response Models

/// タグ抽出レスポンス
struct TagExtractionResponse: Codable {
    let tags: [String]
    let usage: UsageInfo
}

/// メモアレンジレスポンス
struct MemoArrangeResponse: Codable {
    let arrangedContent: String
    let usage: UsageInfo
}

/// カテゴリー要約レスポンス
struct CategorySummaryResponse: Codable {
    let summary: String
    let keyPoints: [String]
    let trends: [String]?
    let usage: UsageInfo
}

/// Pro版AI使用量レスポンス
struct ProAIUsageResponse: Codable {
    let count: Int
    let limit: Int
    let remaining: Int
    let resetDate: String
}

/// 使用量情報
struct UsageInfo: Codable {
    let count: Int
    let limit: Int
    let remaining: Int
}

/// エラーレスポンス
struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Error Types

/// Pro版AIサービスのエラー
enum ProAIError: Error, LocalizedError {
    case proVersionRequired
    case authenticationRequired
    case usageLimitExceeded(String)
    case invalidRequest(String)
    case invalidURL
    case networkError
    case serverError
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .proVersionRequired:
            return "この機能はPro版限定です。Pro版にアップグレードしてください。"
        case .authenticationRequired:
            return "認証が必要です。設定からサインインしてください。"
        case .usageLimitExceeded(let message):
            return message
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        case .invalidURL:
            return "不正なURLです"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .serverError:
            return "サーバーエラーが発生しました。しばらく待ってから再試行してください。"
        case .unknown(let code):
            return "不明なエラーが発生しました（コード: \(code)）"
        }
    }
}
