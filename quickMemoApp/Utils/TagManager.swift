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