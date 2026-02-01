import Foundation
import SwiftUI

class TagManager: ObservableObject {
    static let shared = TagManager()
    
    @Published var suggestionTags: [String] = []
    @Published var popularTags: [String] = []
    
    private let maxSuggestions = 5
    private let maxPopularTags = 10
    
    private init() {}
    
    @MainActor
    func generateTagSuggestions(for text: String, category: String) -> [String] {
        let words = extractKeywords(from: text)
        let categoryTags = getCategoryDefaultTags(category: category)
        let frequentTags = getFrequentTags()
        
        var suggestions: [String] = []
        
        suggestions.append(contentsOf: categoryTags.prefix(2))
        
        for word in words.prefix(2) {
            if !suggestions.contains(word) && word.count >= 2 {
                suggestions.append(word)
            }
        }
        
        for tag in frequentTags {
            if suggestions.count >= maxSuggestions { break }
            if !suggestions.contains(tag) {
                suggestions.append(tag)
            }
        }
        
        return Array(suggestions.prefix(maxSuggestions))
    }
    
    private func extractKeywords(from text: String) -> [String] {
        let stopWords = Set(["の", "は", "が", "を", "に", "で", "と", "から", "まで", "より", "です", "である", "する", "した", "します", "ます", "だ", "である"])

        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 && !stopWords.contains($0) }

        return Array(Set(words))
    }

    // MARK: - Hashtag Extraction

    /// テキストから#タグ形式のハッシュタグを自動抽出
    func extractHashtagsFromText(_ text: String) -> [String] {
        // 正規表現パターン: # の後に続く文字（日本語、英数字、アンダースコア）
        let pattern = "#([\\p{L}\\p{N}_]+)"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

            var hashtags: [String] = []
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let hashtag = String(text[range])
                    // タグの長さが1文字以上20文字以下の場合のみ追加
                    if hashtag.count >= 1 && hashtag.count <= 20 {
                        hashtags.append(hashtag)
                    }
                }
            }

            // 重複を除去して返す
            return Array(Set(hashtags))
        } catch {
            print("❌ Failed to extract hashtags: \(error)")
            return []
        }
    }

    /// テキストからハッシュタグを除去した本文を取得
    func removeHashtagsFromText(_ text: String) -> String {
        let pattern = "#[\\p{L}\\p{N}_]+"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let cleanedText = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(location: 0, length: text.utf16.count),
                withTemplate: ""
            )
            // 余分な空白を整理
            return cleanedText
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        } catch {
            print("❌ Failed to remove hashtags: \(error)")
            return text
        }
    }
    
    @MainActor
    private func getCategoryDefaultTags(category: String) -> [String] {
        return DataManager.shared.getCategory(named: category)?.defaultTags ?? []
    }
    
    @MainActor
    private func getFrequentTags() -> [String] {
        let allTags = DataManager.shared.memos
            .suffix(100)
            .flatMap { $0.tags }
        
        let tagFrequency = Dictionary(grouping: allTags, by: { $0 })
            .mapValues { $0.count }
        
        return tagFrequency
            .sorted { $0.value > $1.value }
            .prefix(maxPopularTags)
            .map { $0.key }
    }
    
    func recordTagUsage(_ tags: [String]) {
        updatePopularTags()
    }
    
    private func updatePopularTags() {
        Task { @MainActor in
            let frequentTags = self.getFrequentTags()
            self.popularTags = frequentTags
        }
    }
}