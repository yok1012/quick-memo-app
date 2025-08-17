import Foundation
import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var memos: [QuickMemo] = []
    @Published var categories: [Category] = []
    
    private let memosKey = "quick_memos"
    private let categoriesKey = "categories"
    
    init() {
        loadData()
        initializeDefaultCategories()
    }
    
    // MARK: - Data Loading/Saving
    
    private func loadData() {
        loadMemos()
        loadCategories()
    }
    
    private func loadMemos() {
        if let data = UserDefaults.standard.data(forKey: memosKey),
           let decodedMemos = try? JSONDecoder().decode([QuickMemo].self, from: data) {
            memos = decodedMemos
        }
    }
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decodedCategories = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decodedCategories
        }
    }
    
    private func saveMemos() {
        if let data = try? JSONEncoder().encode(memos) {
            UserDefaults.standard.set(data, forKey: memosKey)
        }
    }
    
    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: categoriesKey)
        }
    }
    
    // MARK: - Memo Operations
    
    func addMemo(_ memo: QuickMemo) {
        memos.append(memo)
        saveMemos()
    }
    
    func deleteMemo(id: UUID) {
        memos.removeAll { $0.id == id }
        saveMemos()
    }
    
    func updateMemo(_ memo: QuickMemo) {
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            memos[index] = memo
            saveMemos()
        }
    }
    
    // MARK: - Category Operations
    
    func getCategory(named name: String) -> Category? {
        return categories.first { $0.name == name }
    }
    
    // MARK: - Search and Filter
    
    func filteredMemos(category: String, searchText: String = "") -> [QuickMemo] {
        var filtered = memos
        
        if category != "すべて" {
            filtered = filtered.filter { $0.primaryCategory == category }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    func searchMemos(
        searchText: String,
        categories: Set<String>,
        tags: Set<String>,
        startDate: Date?,
        endDate: Date?
    ) -> [QuickMemo] {
        var filtered = memos
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !categories.isEmpty {
            filtered = filtered.filter { categories.contains($0.primaryCategory) }
        }
        
        if !tags.isEmpty {
            filtered = filtered.filter { memo in
                tags.allSatisfy { tag in
                    memo.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
                }
            }
        }
        
        if let startDate = startDate {
            filtered = filtered.filter { $0.createdAt >= startDate }
        }
        
        if let endDate = endDate {
            filtered = filtered.filter { $0.createdAt <= endDate }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getAllTags() -> [String] {
        let allTags = memos.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    // MARK: - Default Categories
    
    private func initializeDefaultCategories() {
        if categories.isEmpty {
            let defaultCategories = [
                Category(name: "仕事", icon: "briefcase", color: "#007AFF", order: 0, defaultTags: ["会議", "タスク", "締切", "アイデア"]),
                Category(name: "プライベート", icon: "house", color: "#34C759", order: 1, defaultTags: ["買い物", "予定", "思い出", "健康"]),
                Category(name: "アイデア", icon: "lightbulb", color: "#FF9500", order: 2, defaultTags: ["ビジネス", "創作", "改善", "メモ"]),
                Category(name: "人物", icon: "person", color: "#AF52DE", order: 3, defaultTags: ["連絡先", "会話", "約束", "関係"]),
                Category(name: "その他", icon: "folder", color: "#8E8E93", order: 4, defaultTags: ["雑記", "一時", "分類待ち", "保留"])
            ]
            
            categories = defaultCategories
            saveCategories()
        }
    }
}