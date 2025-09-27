import Foundation
import SwiftUI
import CoreData
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var memos: [QuickMemo] = []
    @Published var categories: [Category] = []

    nonisolated private let purchaseManager = PurchaseManager.shared
    nonisolated private let coreDataStack = CoreDataStack.shared
    private var iCloudSyncEnabled = false

    private let memosKey = "quick_memos"
    private let categoriesKey = "categories"
    private let widgetCategoriesKey = "widget_categories"
    private let isProVersionKey = "is_pro_version"

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
        setupiCloudSync()
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
    
    // MARK: - iCloud Sync Setup

    private func setupiCloudSync() {
        // 一時的にiCloud同期を無効化（CloudKit設定が完了するまで）
        Task { @MainActor in
            iCloudSyncEnabled = false // purchaseManager.canUseiCloudSync()
            if iCloudSyncEnabled {
                print("✅ iCloud同期が有効になりました（Pro版）")
                await syncWithCoreData()
            } else {
                print("ℹ️ iCloud同期は無効です（無料版）")
            }
        }

        // Listen for Pro version changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(purchaseStatusChanged),
            name: NSNotification.Name("PurchaseStatusChanged"),
            object: nil
        )
    }

    @objc private func purchaseStatusChanged() {
        Task { @MainActor in
            // 一時的にiCloud同期を無効化
            let wasEnabled = iCloudSyncEnabled
            iCloudSyncEnabled = false // purchaseManager.canUseiCloudSync()

            if !wasEnabled && iCloudSyncEnabled {
                print("🎉 Pro版にアップグレード - iCloud同期を開始")
                await migrateUserDefaultsToCoreData()
                await syncWithCoreData()
            }
        }
    }

    // MARK: - Core Data Sync

    private func syncWithCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            // Load from Core Data
            let coreDataMemos = coreDataStack.fetchMemos()
            let coreDataCategories = coreDataStack.fetchCategories()

            // Merge with existing data (UserDefaults has priority for local changes)
            mergeMemos(from: coreDataMemos)
            mergeCategories(from: coreDataCategories)
        }
    }

    private func migrateUserDefaultsToCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            print("📤 UserDefaultsからCore Dataへデータ移行開始")

            // Migrate all memos to Core Data
            for memo in memos {
                coreDataStack.saveMemo(memo)
            }

            // Migrate all categories to Core Data
            for category in categories {
                coreDataStack.saveCategory(category)
            }

            print("✅ データ移行完了: \(memos.count)件のメモ, \(categories.count)件のカテゴリー")
        }
    }

    private func mergeMemos(from coreDataMemos: [QuickMemo]) {
        // Simple merge strategy: combine unique memos
        var memoDict = Dictionary(uniqueKeysWithValues: memos.map { ($0.id, $0) })

        for cdMemo in coreDataMemos {
            if let existingMemo = memoDict[cdMemo.id] {
                // Use the newer version
                if cdMemo.updatedAt > existingMemo.updatedAt {
                    memoDict[cdMemo.id] = cdMemo
                }
            } else {
                memoDict[cdMemo.id] = cdMemo
            }
        }

        memos = Array(memoDict.values).sorted { $0.createdAt > $1.createdAt }
    }

    private func mergeCategories(from coreDataCategories: [Category]) {
        // Simple merge strategy: combine unique categories
        var categoryDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        for cdCategory in coreDataCategories {
            if categoryDict[cdCategory.id] == nil {
                categoryDict[cdCategory.id] = cdCategory
            }
        }

        categories = Array(categoryDict.values).sorted { $0.order < $1.order }
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
        // Always save to UserDefaults for widgets
        if let data = try? JSONEncoder().encode(memos) {
            userDefaults.set(data, forKey: memosKey)
            // Notify widget to update
            notifyWidgetUpdate()
        }

        // Also save to Core Data if Pro version
        if iCloudSyncEnabled {
            Task {
                await saveMemosToCoreData()
            }
        }
    }

    private func saveMemosToCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            for memo in memos {
                coreDataStack.saveMemo(memo)
            }
        }
    }
    
    private func saveCategories() {
        // Always save to UserDefaults for widgets
        if let data = try? JSONEncoder().encode(categories) {
            userDefaults.set(data, forKey: categoriesKey)
            // Notify widget to update
            notifyWidgetUpdate()
        }

        // Also save to Core Data if Pro version
        if iCloudSyncEnabled {
            Task {
                await saveCategoriesToCoreData()
            }
        }
    }

    private func saveCategoriesToCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            for category in categories {
                coreDataStack.saveCategory(category)
            }
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
        var newMemo = memo

        // Enforce tag limit for free users
        if !purchaseManager.isProVersion {
            let maxTags = purchaseManager.getMaxTagsPerMemo()
            if newMemo.tags.count > maxTags {
                print("⚠️ タグ数制限: \(newMemo.tags.count) → \(maxTags)")
                newMemo.tags = Array(newMemo.tags.prefix(maxTags))
            }
        }

        memos.append(newMemo)
        saveMemos()

        // Save to Core Data if Pro version
        if iCloudSyncEnabled {
            coreDataStack.saveMemo(newMemo)
        }
    }
    
    func deleteMemo(id: UUID) {
        memos.removeAll { $0.id == id }
        saveMemos()

        // Delete from Core Data if Pro version
        if iCloudSyncEnabled {
            coreDataStack.deleteMemo(id: id)
        }
    }
    
    func updateMemo(_ memo: QuickMemo) {
        var updatedMemo = memo

        // Enforce tag limit for free users
        if !purchaseManager.isProVersion {
            let maxTags = purchaseManager.getMaxTagsPerMemo()
            if updatedMemo.tags.count > maxTags {
                print("⚠️ タグ数制限: \(updatedMemo.tags.count) → \(maxTags)")
                updatedMemo.tags = Array(updatedMemo.tags.prefix(maxTags))
            }
        }

        if let index = memos.firstIndex(where: { $0.id == updatedMemo.id }) {
            memos[index] = updatedMemo
            saveMemos()

            // Update in Core Data if Pro version
            if iCloudSyncEnabled {
                coreDataStack.saveMemo(updatedMemo)
            }
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

    func addTag(to categoryName: String, tag: String) -> Bool {
        guard var category = getCategory(named: categoryName) else { return false }

        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return false }

        // Check tag limit for free users
        if !purchaseManager.isProVersion {
            let maxTags = purchaseManager.getMaxTagsPerMemo()
            if category.defaultTags.count >= maxTags {
                print("⚠️ カテゴリーのデフォルトタグ数が制限に達しています: \(maxTags)")
                return false
            }
        }

        if !category.defaultTags.contains(trimmedTag) {
            category.defaultTags.append(trimmedTag)
            updateCategory(category)
            return true
        }
        return false
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
    
    // MARK: - Purchase Validation
    
    @MainActor
    func canAddMemo() -> Bool {
        return purchaseManager.canCreateMoreMemos(currentCount: memos.count)
    }
    
    @MainActor
    func canAddCategory() -> Bool {
        return purchaseManager.canCreateMoreCategories(currentCount: categories.count)
    }
    
    @MainActor
    func canUseAdvancedTags() -> Bool {
        return purchaseManager.canUseAdvancedFeatures()
    }
    
    @MainActor
    func canUseCalendarIntegration() -> Bool {
        return purchaseManager.canUseAdvancedFeatures()
    }
    
    @MainActor
    func canUseDeepLinks() -> Bool {
        return purchaseManager.canUseAdvancedFeatures()
    }
    
    @MainActor
    func getRemainingMemoCount() -> Int? {
        if purchaseManager.isProVersion {
            return nil // Unlimited
        }
        return max(0, 100 - memos.count)
    }
    
    @MainActor
    func getRemainingCategoryCount() -> Int? {
        if purchaseManager.isProVersion {
            return nil // Unlimited
        }
        return max(0, 3 - categories.count)
    }

    // MARK: - Widget Management

    func getWidgetCategories() -> [String] {
        // Get selected widget categories from UserDefaults
        if let data = userDefaults.data(forKey: widgetCategoriesKey),
           let categories = try? JSONDecoder().decode([String].self, from: data) {
            return categories
        }
        // Default to first 4 categories
        return Array(categories.prefix(4).map { $0.name })
    }

    @MainActor
    func saveWidgetCategories(_ categoryNames: [String]) {
        if let data = try? JSONEncoder().encode(categoryNames) {
            userDefaults.set(data, forKey: widgetCategoriesKey)
            // Save Pro status for widget
            userDefaults.set(purchaseManager.isProVersion, forKey: isProVersionKey)
            notifyWidgetUpdate()
        }
    }

    @MainActor
    func canCustomizeWidgetCategories() -> Bool {
        return purchaseManager.canCustomizeWidget()
    }
}