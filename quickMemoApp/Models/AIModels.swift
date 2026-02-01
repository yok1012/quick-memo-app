import Foundation

// MARK: - AI Request Types

enum AIRequestType {
    case tagExtraction(content: String)
    case memoArrange(content: String, instruction: String)
    case categorySummary(memos: [String])
}

// MARK: - AI Response

struct AIResponse {
    let type: AIRequestType
    let result: String
    let tokensUsed: Int
    let cost: Double
    let provider: String
    let timestamp: Date

    init(type: AIRequestType, result: String, tokensUsed: Int = 0, cost: Double = 0, provider: String) {
        self.type = type
        self.result = result
        self.tokensUsed = tokensUsed
        self.cost = cost
        self.provider = provider
        self.timestamp = Date()
    }
}

// MARK: - Tag Extraction Result

struct TagExtractionResult: Codable {
    let tags: [String]
    let confidence: Double?

    init(tags: [String], confidence: Double? = nil) {
        self.tags = tags
        self.confidence = confidence
    }
}

// MARK: - Category Summary Result

struct CategorySummaryResult: Codable {
    let summary: String
    let keyPoints: [String]
    let trends: [String]?
    let totalMemos: Int

    init(summary: String, keyPoints: [String], trends: [String]? = nil, totalMemos: Int) {
        self.summary = summary
        self.keyPoints = keyPoints
        self.trends = trends
        self.totalMemos = totalMemos
    }
}

// MARK: - AI Service Error

enum AIServiceError: Error, LocalizedError {
    case apiKeyNotFound
    case invalidResponse
    case networkError(Error)
    case rateLimitExceeded
    case quotaExceeded
    case invalidRequest(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotFound:
            return "APIキーが設定されていません。設定画面からAPIキーを登録してください。"
        case .invalidResponse:
            return "APIからの応答が不正です。"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "リクエスト制限に達しました。しばらく待ってから再試行してください。"
        case .quotaExceeded:
            return "月間の使用量制限に達しました。"
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        }
    }
}

// MARK: - AI Usage Stats

struct AIUsageStats: Codable {
    var totalRequests: Int
    var requestsByType: [String: Int]
    var totalTokens: Int
    var totalCost: Double
    var lastResetDate: Date
    var monthlyLimit: Int

    init(monthlyLimit: Int = 100) {
        self.totalRequests = 0
        self.requestsByType = [:]
        self.totalTokens = 0
        self.totalCost = 0.0
        self.lastResetDate = Date()
        self.monthlyLimit = monthlyLimit
    }

    mutating func recordUsage(type: String, tokens: Int, cost: Double) {
        totalRequests += 1
        requestsByType[type, default: 0] += 1
        totalTokens += tokens
        totalCost += cost
    }

    mutating func resetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()

        if !calendar.isDate(lastResetDate, equalTo: now, toGranularity: .month) {
            // 月が変わったらリセット
            totalRequests = 0
            requestsByType = [:]
            totalTokens = 0
            totalCost = 0.0
            lastResetDate = now
        }
    }

    var remainingRequests: Int {
        return max(0, monthlyLimit - totalRequests)
    }

    var isQuotaExceeded: Bool {
        return totalRequests >= monthlyLimit
    }
}

// MARK: - AI Usage Log Entry

/// 個別のAI使用履歴エントリ（詳細ログ用）
struct AIUsageLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let requestType: String // "tag_extraction", "memo_arrange", "category_summary"
    let provider: String // "gemini", "claude"
    let model: String // "gemini-1.5-flash", "claude-3-5-haiku-20241022"
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let estimatedCost: Double
    let contentLength: Int // 入力テキストの文字数
    let success: Bool
    let errorMessage: String?

    init(
        requestType: String,
        provider: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        contentLength: Int,
        estimatedCost: Double,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.requestType = requestType
        self.provider = provider
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
        self.estimatedCost = estimatedCost
        self.contentLength = contentLength
        self.success = success
        self.errorMessage = errorMessage
    }

    /// 表示用のリクエストタイプ名
    var displayRequestType: String {
        switch requestType {
        case "tag_extraction":
            return "タグ抽出"
        case "memo_arrange":
            return "メモアレンジ"
        case "category_summary":
            return "カテゴリー要約"
        default:
            return requestType
        }
    }

    /// 表示用のプロバイダー名
    var displayProvider: String {
        switch provider {
        case "gemini":
            return "Gemini"
        case "claude":
            return "Claude"
        default:
            return provider
        }
    }
}

// MARK: - AI Usage History

/// AI使用履歴の管理
struct AIUsageHistory: Codable {
    var logs: [AIUsageLogEntry]

    init() {
        self.logs = []
    }

    /// ログエントリを追加
    mutating func addLog(_ entry: AIUsageLogEntry) {
        logs.append(entry)

        // 古いログを削除（最新1000件のみ保持）
        if logs.count > 1000 {
            logs = Array(logs.suffix(1000))
        }
    }

    /// 期間でフィルタ
    func filterByDate(from startDate: Date, to endDate: Date) -> [AIUsageLogEntry] {
        return logs.filter { log in
            log.timestamp >= startDate && log.timestamp <= endDate
        }
    }

    /// 今月のログ
    func currentMonthLogs() -> [AIUsageLogEntry] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        return logs.filter { $0.timestamp >= startOfMonth }
    }

    /// リクエストタイプ別の統計
    func statsByRequestType() -> [String: (count: Int, totalCost: Double, totalTokens: Int)] {
        var stats: [String: (count: Int, totalCost: Double, totalTokens: Int)] = [:]

        for log in logs {
            let current = stats[log.requestType] ?? (0, 0.0, 0)
            stats[log.requestType] = (
                count: current.count + 1,
                totalCost: current.totalCost + log.estimatedCost,
                totalTokens: current.totalTokens + log.totalTokens
            )
        }

        return stats
    }

    /// プロバイダー別の統計
    func statsByProvider() -> [String: (count: Int, totalCost: Double, totalTokens: Int)] {
        var stats: [String: (count: Int, totalCost: Double, totalTokens: Int)] = [:]

        for log in logs {
            let current = stats[log.provider] ?? (0, 0.0, 0)
            stats[log.provider] = (
                count: current.count + 1,
                totalCost: current.totalCost + log.estimatedCost,
                totalTokens: current.totalTokens + log.totalTokens
            )
        }

        return stats
    }

    /// 日別の統計
    func dailyStats(days: Int = 30) -> [(date: Date, count: Int, cost: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var stats: [Date: (count: Int, cost: Double)] = [:]

        // 過去N日分の日付を準備
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: now) {
                let startOfDay = calendar.startOfDay(for: date)
                stats[startOfDay] = (0, 0.0)
            }
        }

        // ログを日別に集計
        for log in logs {
            let startOfDay = calendar.startOfDay(for: log.timestamp)
            if stats[startOfDay] != nil {
                let current = stats[startOfDay] ?? (0, 0.0)
                stats[startOfDay] = (current.count + 1, current.cost + log.estimatedCost)
            }
        }

        return stats.map { (date: $0.key, count: $0.value.count, cost: $0.value.cost) }
            .sorted { $0.date < $1.date }
    }

    /// CSVエクスポート用の文字列生成
    func exportToCSV() -> String {
        var csv = "日時,リクエスト種類,プロバイダー,モデル,入力トークン,出力トークン,合計トークン,推定コスト,入力文字数,成功,エラーメッセージ\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for log in logs.sorted(by: { $0.timestamp > $1.timestamp }) {
            csv += "\(formatter.string(from: log.timestamp)),"
            csv += "\(log.displayRequestType),"
            csv += "\(log.displayProvider),"
            csv += "\(log.model),"
            csv += "\(log.inputTokens),"
            csv += "\(log.outputTokens),"
            csv += "\(log.totalTokens),"
            csv += "\(String(format: "%.6f", log.estimatedCost)),"
            csv += "\(log.contentLength),"
            csv += "\(log.success ? "成功" : "失敗"),"
            csv += "\(log.errorMessage ?? "")\n"
        }

        return csv
    }
}

// MARK: - AI Provider & Model Selection

/// AIプロバイダー
enum AIProvider: String, Codable, CaseIterable {
    case gemini = "gemini"
    case claude = "claude"
    case chatgpt = "chatgpt"

    var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        }
    }

    /// プロバイダーで利用可能なモデル一覧
    var availableModels: [AIModel] {
        switch self {
        case .gemini:
            return [
                AIModel(id: "gemini-3-flash", name: "Gemini 3 Flash", provider: .gemini, inputCost: 0.50, outputCost: 3.00, description: "最速・最軽量"),
                AIModel(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", provider: .gemini, inputCost: 0.30, outputCost: 2.50, description: "バランス重視"),
                AIModel(id: "gemini-3-pro", name: "Gemini 3 Pro", provider: .gemini, inputCost: 2.00, outputCost: 12.00, description: "最高性能"),
                AIModel(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", provider: .gemini, inputCost: 1.25, outputCost: 10.00, description: "長文読解特化")
            ]
        case .claude:
            return [
                AIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: .claude, inputCost: 0.80, outputCost: 4.00, description: "高速・バランス型"),
                AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: .claude, inputCost: 3.00, outputCost: 15.00, description: "高性能・汎用"),
                AIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: .claude, inputCost: 15.00, outputCost: 75.00, description: "最高性能")
            ]
        case .chatgpt:
            return [
                // GPT-5系列のみ（nanoは性能不足のため除外）
                AIModel(id: "gpt-5-mini", name: "GPT-5 Mini", provider: .chatgpt, inputCost: 0.40, outputCost: 1.60, cachedInputCost: 0.10, description: "軽量・低コスト"),
                AIModel(id: "gpt-5", name: "GPT-5", provider: .chatgpt, inputCost: 2.00, outputCost: 8.00, cachedInputCost: 0.50, description: "標準・汎用"),
                AIModel(id: "gpt-5.1", name: "GPT-5.1", provider: .chatgpt, inputCost: 3.00, outputCost: 12.00, cachedInputCost: 0.75, description: "高性能"),
                AIModel(id: "gpt-5.2", name: "GPT-5.2", provider: .chatgpt, inputCost: 5.00, outputCost: 20.00, cachedInputCost: 1.25, description: "最高性能")
            ]
        }
    }
}

/// AIモデル情報
struct AIModel: Codable, Identifiable, Equatable {
    let id: String // モデルID（API呼び出し用）
    let name: String // 表示名
    let provider: AIProvider
    let inputCost: Double // 入力コスト（$per 1M tokens）
    let outputCost: Double // 出力コスト（$per 1M tokens）
    let cachedInputCost: Double? // キャッシュ入力コスト（$per 1M tokens）- OpenAI特有
    let description: String // 説明

    init(id: String, name: String, provider: AIProvider, inputCost: Double, outputCost: Double, cachedInputCost: Double? = nil, description: String) {
        self.id = id
        self.name = name
        self.provider = provider
        self.inputCost = inputCost
        self.outputCost = outputCost
        self.cachedInputCost = cachedInputCost
        self.description = description
    }

    /// コスト表示用の文字列
    var costDisplay: String {
        if let cached = cachedInputCost {
            return String(format: "$%.2f ($%.3f cached) / $%.2f", inputCost, cached, outputCost)
        }
        return String(format: "$%.2f / $%.2f", inputCost, outputCost)
    }
}

/// 機能別のモデル設定
struct AIModelPreferences: Codable {
    var tagExtraction: AIModelSelection
    var memoArrange: AIModelSelection
    var categorySummary: AIModelSelection

    init() {
        // デフォルト設定（GPT-5シリーズを使用）
        self.tagExtraction = AIModelSelection(provider: .chatgpt, modelId: "gpt-5-mini")
        self.memoArrange = AIModelSelection(provider: .chatgpt, modelId: "gpt-5-mini")
        self.categorySummary = AIModelSelection(provider: .chatgpt, modelId: "gpt-5-mini")
    }
}

/// モデル選択
struct AIModelSelection: Codable {
    var provider: AIProvider
    var modelId: String

    /// 実際のモデル情報を取得
    func getModel() -> AIModel? {
        return provider.availableModels.first { $0.id == modelId }
    }
}
