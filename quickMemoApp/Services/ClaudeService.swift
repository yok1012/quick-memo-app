import Foundation

/// Claude API連携サービス（メモアレンジ・要約用）
class ClaudeService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-3-5-haiku-20241022"
    private let apiVersion = "2023-06-01"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Tag Extraction

    /// メモ内容からタグを抽出
    func extractTags(from content: String, model: String = "claude-3-5-haiku-20241022") async throws -> TagExtractionResult {
        let prompt = """
        以下のメモ内容から、関連性の高いタグを3〜5個抽出してください。
        タグは日本語または英語の単語で、カンマ区切りで出力してください。
        タグのみを出力し、説明は不要です。

        メモ内容:
        \(content)

        タグ:
        """

        let text = try await sendMessage(prompt: prompt, model: model, maxTokens: 100)

        // カンマ区切りのタグをパース
        let tags = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return TagExtractionResult(tags: tags)
    }

    // MARK: - Memo Arrange

    /// メモを指示に基づいてアレンジ
    func arrangeMemo(content: String, instruction: String, model: String = "claude-3-5-haiku-20241022") async throws -> String {
        let prompt = """
        以下のメモを、指定された指示に従って編集してください。
        編集後のメモのみを出力し、説明は不要です。

        【元のメモ】
        \(content)

        【指示】
        \(instruction)

        【編集後のメモ】
        """

        return try await sendMessage(prompt: prompt, model: model, maxTokens: 1000)
    }

    // MARK: - Category Summary

    /// カテゴリー内のメモを要約
    func summarizeCategory(memos: [String], categoryName: String, model: String = "claude-3-5-haiku-20241022") async throws -> CategorySummaryResult {
        let memosText = memos.enumerated().map { index, memo in
            "\(index + 1). \(memo)"
        }.joined(separator: "\n\n")

        let prompt = """
        以下は「\(categoryName)」カテゴリーのメモ一覧です。
        これらのメモを分析し、以下の形式でJSON形式で出力してください。

        {
          "summary": "全体の要約（200文字以内）",
          "keyPoints": ["要点1", "要点2", "要点3"],
          "trends": ["トレンド1", "トレンド2"]
        }

        【メモ一覧】
        \(memosText)

        JSON:
        """

        let jsonResponse = try await sendMessage(prompt: prompt, model: model, maxTokens: 1500)

        // JSONパース
        guard let jsonData = jsonResponse.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        do {
            let decoded = try JSONDecoder().decode(CategorySummaryJSON.self, from: jsonData)
            return CategorySummaryResult(
                summary: decoded.summary,
                keyPoints: decoded.keyPoints,
                trends: decoded.trends,
                totalMemos: memos.count
            )
        } catch {
            // JSONパースに失敗した場合、テキストとして扱う
            return CategorySummaryResult(
                summary: jsonResponse,
                keyPoints: [],
                trends: nil,
                totalMemos: memos.count
            )
        }
    }

    // MARK: - Private Helper

    private func sendMessage(prompt: String, model: String? = nil, maxTokens: Int) async throws -> String {
        let modelToUse = model ?? self.model
        let requestBody = ClaudeRequest(
            model: modelToUse,
            maxTokens: maxTokens,
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ]
        )

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw AIServiceError.rateLimitExceeded
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.invalidRequest(errorMessage)
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" })?.text else {
            throw AIServiceError.invalidResponse
        }

        return textContent
    }
}

// MARK: - Claude API Models

private struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stopReason: String?
    let usage: ClaudeUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

private struct ClaudeContent: Codable {
    let type: String
    let text: String?
}

private struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private struct CategorySummaryJSON: Codable {
    let summary: String
    let keyPoints: [String]
    let trends: [String]?
}
