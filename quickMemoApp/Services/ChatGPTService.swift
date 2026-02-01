import Foundation

/// ChatGPT API連携サービス
class ChatGPTService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Tag Extraction

    /// メモ内容からタグを抽出
    func extractTags(from content: String, model: String = "gpt-5-mini") async throws -> TagExtractionResult {
        let prompt = """
        以下のメモ内容から、関連性の高いタグを3〜5個抽出してください。
        タグは日本語または英語の単語で、カンマ区切りで出力してください。
        タグのみを出力し、説明は不要です。

        メモ内容:
        \(content)

        タグ:
        """

        let text = try await sendMessage(prompt: prompt, model: model, maxTokens: 500)

        // カンマ区切りのタグをパース
        let tags = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return TagExtractionResult(tags: tags)
    }

    // MARK: - Memo Arrange

    /// メモを指示に基づいてアレンジ
    func arrangeMemo(content: String, instruction: String, model: String = "gpt-5-mini") async throws -> String {
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
    func summarizeCategory(memos: [String], categoryName: String, model: String = "gpt-5-mini") async throws -> CategorySummaryResult {
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

    private func sendMessage(prompt: String, model: String, maxTokens: Int) async throws -> String {
        // 新しいOpenAIモデルはtemperatureをサポートしないものが多いため、送信しない
        let requestBody = ChatGPTRequest(
            model: model,
            messages: [
                ChatGPTMessage(role: "user", content: prompt)
            ],
            maxCompletionTokens: maxTokens
        )

        let url = URL(string: "\(baseURL)/chat/completions")!
        print("🔍 Trying ChatGPT model: \(model)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            print("❌ ChatGPT API Error [\(httpResponse.statusCode)] for model \(model): \(errorMessage)")

            if httpResponse.statusCode == 404 {
                throw AIServiceError.invalidRequest("モデル \(model) が見つかりません (404)")
            }

            throw AIServiceError.invalidRequest("エラー[\(httpResponse.statusCode)]: \(errorMessage)")
        }

        // デバッグ: 生のレスポンスを出力
        let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        print("📥 ChatGPT Raw Response: \(rawResponse)")

        let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)

        print("📊 ChatGPT Choices count: \(chatGPTResponse.choices.count)")

        // finish_reasonをチェック
        if let firstChoice = chatGPTResponse.choices.first,
           let finishReason = firstChoice.finishReason {
            print("🔍 ChatGPT finish_reason: \(finishReason)")
            if finishReason == "length" {
                print("⚠️ Response was truncated due to max_tokens limit")
            }
        }

        // 標準フォーマットからコンテンツを取得
        if let firstChoice = chatGPTResponse.choices.first,
           let message = firstChoice.message,
           let content = message.content,
           !content.isEmpty {
            // contentが意味のあるテキストかチェック（引用符だけや空白だけでない）
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 1 || (trimmed.count == 1 && !["'", "\"", "`"].contains(trimmed)) {
                print("✅ ChatGPT extracted text (standard): '\(content)'")
                return content
            } else {
                print("⚠️ ChatGPT content is invalid (quotes or whitespace only): '\(content)'")
                // finish_reasonがlengthの場合は、それを含めたエラーメッセージ
                if let finishReason = firstChoice.finishReason, finishReason == "length" {
                    throw AIServiceError.invalidRequest("モデルが無効な出力を生成しました（トークン制限により途中で切断）。モデルまたはプロンプトを変更してください。")
                }
            }
        }

        // 新しいフォーマット（output）からコンテンツを取得
        if let output = chatGPTResponse.output,
           let message = output.message,
           let content = message.content,
           !content.isEmpty {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 1 || (trimmed.count == 1 && !["'", "\"", "`"].contains(trimmed)) {
                print("✅ ChatGPT extracted text (output): '\(content)'")
                return content
            } else {
                print("⚠️ ChatGPT output content is invalid (quotes or whitespace only): '\(content)'")
            }
        }

        print("❌ ChatGPT: No message content in response")
        print("📥 Full response for debugging: \(rawResponse)")
        // エラーメッセージにレスポンスの一部を含める（デバッグ用）
        let truncatedResponse = String(rawResponse.prefix(500))
        throw AIServiceError.invalidRequest("APIレスポンス解析エラー: \(truncatedResponse)")
    }
}

// MARK: - ChatGPT API Models

private struct ChatGPTRequest: Codable {
    let model: String
    let messages: [ChatGPTMessage]
    let maxCompletionTokens: Int
    // temperatureは新しいモデルでサポートされていないため削除

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct ChatGPTMessage: Codable {
    let role: String
    let content: String?  // オプショナルに変更（新しいモデルではnullの場合がある）
}

private struct ChatGPTResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [ChatGPTChoice]
    let usage: ChatGPTUsage?
    let output: ChatGPTOutput?  // 新しいAPIフォーマット用
}

// 新しいOpenAI APIフォーマット用
private struct ChatGPTOutput: Codable {
    let message: ChatGPTOutputMessage?
}

private struct ChatGPTOutputMessage: Codable {
    let content: String?
}

private struct ChatGPTChoice: Codable {
    let index: Int?
    let message: ChatGPTMessage?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

private struct ChatGPTUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct CategorySummaryJSON: Codable {
    let summary: String
    let keyPoints: [String]
    let trends: [String]?
}
