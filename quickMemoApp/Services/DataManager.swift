import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var memos: [QuickMemo] = []
    @Published var categories: [Category] = []

    private let memosKey = "quick_memos"
    private let categoriesKey = "categories"

    // App Group identifier for widget data sharing
    private let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
    private var userDefaults: UserDefaults
    
    init() {
        // Use App Group's UserDefaults for data sharing with widget
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.userDefaults = groupDefaults
            // Migrate existing data if needed
            migrateDataIfNeeded()
        } else {
            // Fallback to standard UserDefaults if App Group is not available
            self.userDefaults = UserDefaults.standard
        }

        loadData()
        initializeDefaultCategories()
    }

    private func migrateDataIfNeeded() {
        // Migrate data from standard UserDefaults to App Group if needed
        let standard = UserDefaults.standard

        // Migrate memos
        if userDefaults.data(forKey: memosKey) == nil,
           let memosData = standard.data(forKey: memosKey) {
            userDefaults.set(memosData, forKey: memosKey)
            standard.removeObject(forKey: memosKey)
        }

        // Migrate categories
        if userDefaults.data(forKey: categoriesKey) == nil,
           let categoriesData = standard.data(forKey: categoriesKey) {
            userDefaults.set(categoriesData, forKey: categoriesKey)
            standard.removeObject(forKey: categoriesKey)
        }
    }
    
    // MARK: - Data Loading/Saving
    
    private func loadData() {
        loadMemos()
        loadCategories()
    }
    
    private func loadMemos() {
        if let data = userDefaults.data(forKey: memosKey),
           let decodedMemos = try? JSONDecoder().decode([QuickMemo].self, from: data) {
            memos = decodedMemos
        }
    }
    
    private func loadCategories() {
        if let data = userDefaults.data(forKey: categoriesKey),
           let decodedCategories = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decodedCategories
        }
    }
    
    private func saveMemos() {
        if let data = try? JSONEncoder().encode(memos) {
            userDefaults.set(data, forKey: memosKey)
            // Notify widget to update
            notifyWidgetUpdate()
        }
    }
    
    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            userDefaults.set(data, forKey: categoriesKey)
            // Notify widget to update
            notifyWidgetUpdate()
        }
    }

    private func notifyWidgetUpdate() {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    
    // MARK: - Memo Operations
    
    func addMemo(_ memo: QuickMemo) {
        memos.append(memo)
        saveMemos()
        // カレンダー登録処理を削除（FastInputViewで既に実行されているため）
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
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            let oldName = categories[index].name
            categories[index] = category

            // Update memos if category name changed
            if oldName != category.name {
                updateMemosWithCategoryChange(oldName: oldName, newName: category.name)
            }

            saveCategories()
        }
    }

    func addCategory(_ category: Category) {
        // Ensure unique name
        guard !categories.contains(where: { $0.name == category.name }) else {
            print("Category with name '\(category.name)' already exists")
            return
        }

        categories.append(category)
        saveCategories()
    }

    func deleteCategory(id: UUID) {
        guard let category = categories.first(where: { $0.id == id }) else { return }

        // Move all memos from this category to "その他"
        let memosToUpdate = memos.filter { $0.primaryCategory == category.name }
        for memo in memosToUpdate {
            var updatedMemo = memo
            updatedMemo.primaryCategory = "その他"
            updateMemo(updatedMemo)
        }

        categories.removeAll { $0.id == id }
        saveCategories()
    }

    func reorderCategories(_ categories: [Category]) {
        // Update order property based on new arrangement
        for (index, category) in categories.enumerated() {
            if let existingIndex = self.categories.firstIndex(where: { $0.id == category.id }) {
                self.categories[existingIndex].order = index
            }
        }

        // Sort by new order
        self.categories.sort { $0.order < $1.order }
        saveCategories()
    }

    private func updateMemosWithCategoryChange(oldName: String, newName: String) {
        for index in memos.indices {
            if memos[index].primaryCategory == oldName {
                memos[index].primaryCategory = newName
            }
        }
        saveMemos()
    }
    
    // MARK: - Tag Operations
    
    func addTag(to categoryName: String, tag: String) {
        guard var category = getCategory(named: categoryName) else { return }
        
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        
        if !category.defaultTags.contains(trimmedTag) {
            category.defaultTags.append(trimmedTag)
            updateCategory(category)
        }
    }
    
    func removeTag(from categoryName: String, tag: String) {
        guard var category = getCategory(named: categoryName) else { return }
        
        category.defaultTags.removeAll { $0 == tag }
        updateCategory(category)
    }
    
    func updateTag(in categoryName: String, oldTag: String, newTag: String) {
        guard var category = getCategory(named: categoryName) else { return }
        
        let trimmedNewTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewTag.isEmpty else { return }
        
        if let index = category.defaultTags.firstIndex(of: oldTag) {
            category.defaultTags[index] = trimmedNewTag
            updateCategory(category)
        }
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

    // カテゴリー名が変更された場合の検証
    func canRenameCategory(from oldName: String, to newName: String) -> Bool {
        // その他カテゴリーは名前変更不可
        if oldName == "その他" {
            return false
        }

        // 既存のカテゴリー名との重複チェック
        return !categories.contains { $0.name == newName && $0.name != oldName }
    }

    // カテゴリーが削除可能かチェック
    func canDeleteCategory(_ category: Category) -> Bool {
        // その他カテゴリーは削除不可
        return category.name != "その他"
    }
}