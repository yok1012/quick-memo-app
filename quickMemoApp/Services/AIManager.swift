import Foundation
import SwiftUI

/// AI機能の統合管理マネージャー
@MainActor
class AIManager: ObservableObject {
    static let shared = AIManager()

    // MARK: - Published Properties

    @Published var usageStats: AIUsageStats
    @Published var usageHistory: AIUsageHistory
    @Published var isProcessing: Bool = false
    @Published var lastError: String?
    @Published var modelPreferences: AIModelPreferences

    // MARK: - Services

    private var geminiService: GeminiService?
    private var claudeService: ClaudeService?
    private var chatGPTService: ChatGPTService?

    // MARK: - Constants

    private let usageStatsKey = "ai_usage_stats"
    private let usageHistoryKey = "ai_usage_history"
    private let modelPreferencesKey = "ai_model_preferences"

    // MARK: - Initialization

    private init() {
        // 使用統計を読み込み
        if let data = UserDefaults.standard.data(forKey: usageStatsKey),
           let stats = try? JSONDecoder().decode(AIUsageStats.self, from: data) {
            self.usageStats = stats
        } else {
            self.usageStats = AIUsageStats()
        }

        // 使用履歴を読み込み
        if let data = UserDefaults.standard.data(forKey: usageHistoryKey),
           let history = try? JSONDecoder().decode(AIUsageHistory.self, from: data) {
            self.usageHistory = history
        } else {
            self.usageHistory = AIUsageHistory()
        }

        // モデル設定を読み込み
        if let data = UserDefaults.standard.data(forKey: modelPreferencesKey),
           let preferences = try? JSONDecoder().decode(AIModelPreferences.self, from: data) {
            self.modelPreferences = preferences
        } else {
            self.modelPreferences = AIModelPreferences()
        }

        // 月次リセットチェック
        usageStats.resetIfNeeded()
        saveUsageStats()

        // サービスの初期化
        initializeServices()
    }

    // MARK: - Service Initialization

    private func initializeServices() {
        // Gemini Service
        if let geminiKey = KeychainManager.get(for: .gemini) {
            geminiService = GeminiService(apiKey: geminiKey)
        }

        // Claude Service
        if let claudeKey = KeychainManager.get(for: .claude) {
            claudeService = ClaudeService(apiKey: claudeKey)
        }

        // ChatGPT Service
        if let chatGPTKey = KeychainManager.get(for: .openai) {
            chatGPTService = ChatGPTService(apiKey: chatGPTKey)
        }
    }

    // MARK: - API Key Management

    /// APIキーを設定
    func setAPIKey(_ key: String, for provider: KeychainManager.APIProvider) throws {
        try KeychainManager.save(apiKey: key, for: provider)
        initializeServices()
    }

    /// APIキーの存在確認
    func hasAPIKey(for provider: KeychainManager.APIProvider) -> Bool {
        return KeychainManager.exists(for: provider)
    }

    /// APIキーを削除
    func deleteAPIKey(for provider: KeychainManager.APIProvider) throws {
        try KeychainManager.delete(for: provider)
        initializeServices()
    }

    /// メモからタグを抽出（設定されたモデルを使用）
    func extractTags(from content: String) async throws -> [String] {
        // 使用量チェック
        guard !usageStats.isQuotaExceeded else {
            throw AIServiceError.quotaExceeded
        }

        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()
        let contentLength = content.count
        let selection = modelPreferences.tagExtraction
        let provider = selection.provider
        let modelId = selection.modelId

        // モデル情報を取得してコスト計算に使用
        let model = selection.getModel()
        let inputCostPer1M = model?.inputCost ?? 0.30
        let outputCostPer1M = model?.outputCost ?? 2.50

        do {
            let result: TagExtractionResult

            // プロバイダーに応じてサービスを選択
            switch provider {
            case .gemini:
                guard let service = geminiService else {
                    throw AIServiceError.apiKeyNotFound
                }
                result = try await service.extractTags(from: content, model: modelId)

            case .claude:
                guard let service = claudeService else {
                    throw AIServiceError.apiKeyNotFound
                }
                result = try await service.extractTags(from: content, model: modelId)

            case .chatgpt:
                guard let service = chatGPTService else {
                    throw AIServiceError.apiKeyNotFound
                }
                result = try await service.extractTags(from: content, model: modelId)
            }

            // トークン数の推定
            let estimatedInputTokens = Int(Double(contentLength) * 1.5)
            let estimatedOutputTokens = result.tags.joined(separator: ",").count
            let totalTokens = estimatedInputTokens + estimatedOutputTokens

            // コスト計算（選択されたモデルの料金を使用）
            let inputCost = Double(estimatedInputTokens) / 1_000_000.0 * inputCostPer1M
            let outputCost = Double(estimatedOutputTokens) / 1_000_000.0 * outputCostPer1M
            let totalCost = inputCost + outputCost

            // 使用統計を記録
            recordUsage(type: "tag_extraction", tokens: totalTokens, cost: totalCost)

            // 詳細ログを記録
            let logEntry = AIUsageLogEntry(
                requestType: "tag_extraction",
                provider: provider.rawValue,
                model: modelId,
                inputTokens: estimatedInputTokens,
                outputTokens: estimatedOutputTokens,
                contentLength: contentLength,
                estimatedCost: totalCost,
                success: true,
                errorMessage: nil
            )
            recordLog(logEntry)

            print("✅ Tag Extraction Success - Provider: \(provider.displayName), Model: \(modelId), Tokens: \(totalTokens), Cost: $\(String(format: "%.6f", totalCost)), Time: \(Date().timeIntervalSince(startTime))s")

            return result.tags
        } catch {
            lastError = error.localizedDescription

            // エラーログを記録
            let logEntry = AIUsageLogEntry(
                requestType: "tag_extraction",
                provider: provider.rawValue,
                model: modelId,
                inputTokens: 0,
                outputTokens: 0,
                contentLength: contentLength,
                estimatedCost: 0.0,
                success: false,
                errorMessage: error.localizedDescription
            )
            recordLog(logEntry)

            print("❌ Tag Extraction Failed - Error: \(error.localizedDescription)")

            throw error
        }
    }

    // MARK: - Memo Arrange

    /// メモを指示に基づいてアレンジ（Claude使用）
    func arrangeMemo(content: String, instruction: String) async throws -> String {
        guard let service = claudeService else {
            throw AIServiceError.apiKeyNotFound
        }

        // 使用量チェック
        guard !usageStats.isQuotaExceeded else {
            throw AIServiceError.quotaExceeded
        }

        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()
        let contentLength = content.count + instruction.count

        do {
            let result = try await service.arrangeMemo(content: content, instruction: instruction)

            // トークン数の推定
            let estimatedInputTokens = Int(Double(content.count + instruction.count) * 1.5)
            let estimatedOutputTokens = Int(Double(result.count) * 1.5)
            let totalTokens = estimatedInputTokens + estimatedOutputTokens

            // コスト計算（Claude 3.5 Haiku: 入力$0.80/1M tokens, 出力$4.00/1M tokens）
            let inputCost = Double(estimatedInputTokens) / 1_000_000.0 * 0.80
            let outputCost = Double(estimatedOutputTokens) / 1_000_000.0 * 4.00
            let totalCost = inputCost + outputCost

            // 使用統計を記録
            recordUsage(type: "memo_arrange", tokens: totalTokens, cost: totalCost)

            // 詳細ログを記録
            let logEntry = AIUsageLogEntry(
                requestType: "memo_arrange",
                provider: "claude",
                model: "claude-3-5-haiku-20241022",
                inputTokens: estimatedInputTokens,
                outputTokens: estimatedOutputTokens,
                contentLength: contentLength,
                estimatedCost: totalCost,
                success: true,
                errorMessage: nil
            )
            recordLog(logEntry)

            print("✅ Memo Arrange Success - Tokens: \(totalTokens), Cost: $\(String(format: "%.6f", totalCost)), Time: \(Date().timeIntervalSince(startTime))s")

            return result
        } catch {
            lastError = error.localizedDescription

            // エラーログを記録
            let logEntry = AIUsageLogEntry(
                requestType: "memo_arrange",
                provider: "claude",
                model: "claude-3-5-haiku-20241022",
                inputTokens: 0,
                outputTokens: 0,
                contentLength: contentLength,
                estimatedCost: 0.0,
                success: false,
                errorMessage: error.localizedDescription
            )
            recordLog(logEntry)

            print("❌ Memo Arrange Failed - Error: \(error.localizedDescription)")

            throw error
        }
    }

    // MARK: - Category Summary

    /// カテゴリー内のメモを要約（Claude使用）
    func summarizeCategory(memos: [QuickMemo], categoryName: String) async throws -> CategorySummaryResult {
        guard let service = claudeService else {
            throw AIServiceError.apiKeyNotFound
        }

        // 使用量チェック
        guard !usageStats.isQuotaExceeded else {
            throw AIServiceError.quotaExceeded
        }

        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()
        let memoContents = memos.map { $0.content }
        let allContent = memoContents.joined(separator: "\n")
        let contentLength = allContent.count

        do {
            let result = try await service.summarizeCategory(memos: memoContents, categoryName: categoryName)

            // トークン数の推定
            let estimatedInputTokens = Int(Double(contentLength) * 1.5)
            let resultLength = result.summary.count + result.keyPoints.joined().count + (result.trends?.joined().count ?? 0)
            let estimatedOutputTokens = Int(Double(resultLength) * 1.5)
            let totalTokens = estimatedInputTokens + estimatedOutputTokens

            // コスト計算（Claude 3.5 Haiku: 入力$0.80/1M tokens, 出力$4.00/1M tokens）
            let inputCost = Double(estimatedInputTokens) / 1_000_000.0 * 0.80
            let outputCost = Double(estimatedOutputTokens) / 1_000_000.0 * 4.00
            let totalCost = inputCost + outputCost

            // 使用統計を記録
            recordUsage(type: "category_summary", tokens: totalTokens, cost: totalCost)

            // 詳細ログを記録
            let logEntry = AIUsageLogEntry(
                requestType: "category_summary",
                provider: "claude",
                model: "claude-3-5-haiku-20241022",
                inputTokens: estimatedInputTokens,
                outputTokens: estimatedOutputTokens,
                contentLength: contentLength,
                estimatedCost: totalCost,
                success: true,
                errorMessage: nil
            )
            recordLog(logEntry)

            print("✅ Category Summary Success - Memos: \(memos.count), Tokens: \(totalTokens), Cost: $\(String(format: "%.6f", totalCost)), Time: \(Date().timeIntervalSince(startTime))s")

            return result
        } catch {
            lastError = error.localizedDescription

            // エラーログを記録
            let logEntry = AIUsageLogEntry(
                requestType: "category_summary",
                provider: "claude",
                model: "claude-3-5-haiku-20241022",
                inputTokens: 0,
                outputTokens: 0,
                contentLength: contentLength,
                estimatedCost: 0.0,
                success: false,
                errorMessage: error.localizedDescription
            )
            recordLog(logEntry)

            print("❌ Category Summary Failed - Error: \(error.localizedDescription)")

            throw error
        }
    }

    // MARK: - Usage Tracking

    private func recordUsage(type: String, tokens: Int, cost: Double) {
        usageStats.recordUsage(type: type, tokens: tokens, cost: cost)
        saveUsageStats()
    }

    private func recordLog(_ entry: AIUsageLogEntry) {
        usageHistory.addLog(entry)
        saveUsageHistory()
    }

    private func saveUsageStats() {
        if let data = try? JSONEncoder().encode(usageStats) {
            UserDefaults.standard.set(data, forKey: usageStatsKey)
        }
    }

    private func saveUsageHistory() {
        if let data = try? JSONEncoder().encode(usageHistory) {
            UserDefaults.standard.set(data, forKey: usageHistoryKey)
        }
    }

    private func saveModelPreferences() {
        if let data = try? JSONEncoder().encode(modelPreferences) {
            UserDefaults.standard.set(data, forKey: modelPreferencesKey)
        }
    }

    /// 使用統計を手動でリセット
    func resetUsageStats() {
        usageStats = AIUsageStats()
        saveUsageStats()
    }

    /// 使用履歴を手動でクリア
    func clearUsageHistory() {
        usageHistory = AIUsageHistory()
        saveUsageHistory()
    }

    /// 使用履歴をCSVでエクスポート
    func exportUsageHistoryCSV() -> String {
        return usageHistory.exportToCSV()
    }

    // MARK: - Model Preferences

    /// モデル設定を更新
    func updateModelPreference(for feature: String, provider: AIProvider, modelId: String) {
        switch feature {
        case "tag_extraction":
            modelPreferences.tagExtraction = AIModelSelection(provider: provider, modelId: modelId)
        case "memo_arrange":
            modelPreferences.memoArrange = AIModelSelection(provider: provider, modelId: modelId)
        case "category_summary":
            modelPreferences.categorySummary = AIModelSelection(provider: provider, modelId: modelId)
        default:
            break
        }
        saveModelPreferences()
    }

    // MARK: - Preset Instructions

    /// メモアレンジ用のプリセット指示
    static let arrangePresets: [String: String] = [
        "summarize": "このメモを3行以内で要約してください。",
        "business": "このメモをビジネス文書風に書き直してください。",
        "casual": "このメモをカジュアルで親しみやすい文章に書き直してください。",
        "translate_en": "このメモを英語に翻訳してください。",
        "translate_ja": "このメモを日本語に翻訳してください。",
        "expand": "このメモをより詳しく、具体的に展開してください。",
        "bullets": "このメモを箇条書き形式に整理してください。"
    ]
}
