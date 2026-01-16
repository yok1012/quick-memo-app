import Foundation

/// Gemini API連携サービス（タグ抽出用）
class GeminiService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

    // 試行するモデルのリスト（優先順位順）
    // Gemini 3 Flash: 最速・最軽量（無料枠15リクエスト/分、有料$0.50/$3.00）
    // Gemini 2.5 Flash: バランス重視（無料枠10リクエスト/分、有料$0.30/$2.50）
    // Gemini 3 Pro: 最高性能・複雑な推論用（有料のみ$2.00/$12.00）
    // Gemini 2.5 Pro: 長文読解に強い（有料のみ$1.25/$10.00）
    private let modelCandidates = [
        "gemini-3-flash",
        "gemini-3-flash-latest",
        "gemini-2.5-flash",
        "gemini-2.5-flash-latest",
        "gemini-3-pro",
        "gemini-2.5-pro"
    ]

    // 成功したモデル名をキャッシュ
    private static var workingModel: String?

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Tag Extraction

    /// メモ内容からタグを抽出（指定モデルを優先）
    func extractTags(from content: String, model: String? = nil) async throws -> TagExtractionResult {
        // モデルが指定されている場合は、そのモデルのみを試す
        if let specificModel = model {
            return try await attemptExtractTags(from: content, model: specificModel)
        }

        // モデルが指定されていない場合は、フォールバック機能を使用
        return try await extractTagsWithFallback(from: content)
    }

    /// メモ内容からタグを抽出（フォールバック機能付き）
    private func extractTagsWithFallback(from content: String) async throws -> TagExtractionResult {
        // キャッシュされた成功モデルがあればそれを最優先で試す
        if let cachedModel = Self.workingModel {
            do {
                let result = try await attemptExtractTags(from: content, model: cachedModel)
                print("✅ Using cached working model: \(cachedModel)")
                return result
            } catch {
                print("⚠️ Cached model \(cachedModel) failed, trying other models...")
                Self.workingModel = nil // キャッシュをクリア
            }
        }

        // すべてのモデル候補を試す
        var lastError: Error?

        for model in modelCandidates {
            do {
                let result = try await attemptExtractTags(from: content, model: model)
                Self.workingModel = model // 成功したモデルをキャッシュ
                print("✅ Found working model: \(model)")
                return result
            } catch let error as AIServiceError {
                lastError = error
                print("⚠️ Model \(model) failed: \(error.localizedDescription)")

                // 404以外のエラーの場合はすぐに終了
                if case .rateLimitExceeded = error {
                    throw error
                }
                if case .invalidRequest(let message) = error {
                    if !message.contains("404") && !message.contains("見つかりません") {
                        throw error
                    }
                }

                // 404の場合は次のモデルを試す
                continue
            } catch {
                lastError = error
                print("⚠️ Model \(model) failed with unexpected error: \(error.localizedDescription)")
                continue
            }
        }

        // すべてのモデルが失敗した場合
        throw lastError ?? AIServiceError.invalidRequest("利用可能なGeminiモデルが見つかりませんでした。APIキーを確認してください。")
    }

    /// 指定されたモデルでタグ抽出を試行
    private func attemptExtractTags(from content: String, model: String) async throws -> TagExtractionResult {
        let prompt = """
        以下のメモ内容から、関連性の高いタグを3〜5個抽出してください。
        タグは日本語または英語の単語で、カンマ区切りで出力してください。
        タグのみを出力し、説明は不要です。

        メモ内容:
        \(content)

        タグ:
        """

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [GeminiPart(text: prompt)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.3,
            
                maxOutputTokens: 100
            )
        )

        let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)")!
        print("🔍 Trying Gemini model: \(model)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            print("❌ Gemini API Error [\(httpResponse.statusCode)] for model \(model): \(errorMessage)")

            if httpResponse.statusCode == 404 {
                throw AIServiceError.invalidRequest("モデル \(model) が見つかりません (404)")
            }

            throw AIServiceError.invalidRequest("エラー[\(httpResponse.statusCode)]: \(errorMessage)")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let firstCandidate = geminiResponse.candidates.first,
              let text = firstCandidate.content.parts.first?.text else {
            throw AIServiceError.invalidResponse
        }

        // カンマ区切りのタグをパース
        let tags = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return TagExtractionResult(tags: tags)
    }
}

// MARK: - Gemini API Models

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?

    init(parts: [GeminiPart], role: String? = nil) {
        self.parts = parts
        self.role = role
    }
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiGenerationConfig: Codable {
    let temperature: Double?
    let maxOutputTokens: Int?
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
}
