import Foundation
import SwiftUI
import Combine

class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()

    @Published var memos: [WatchMemo] = []
    @Published var categories: [WatchCategory] = []

    private let userDefaults = UserDefaults.standard
    private let memosKey = "watchMemos"
    private let categoriesKey = "watchCategories"

    private init() {
        loadData()
        setupDefaultCategoriesIfNeeded()
    }

    private func setupDefaultCategoriesIfNeeded() {
        if categories.isEmpty {
            categories = [
                WatchCategory(name: "仕事", icon: "briefcase", color: "007AFF"),
                WatchCategory(name: "プライベート", icon: "house", color: "34C759"),
                WatchCategory(name: "アイデア", icon: "lightbulb", color: "FF9500"),
                WatchCategory(name: "人物", icon: "person", color: "AF52DE"),
                WatchCategory(name: "その他", icon: "folder", color: "8E8E93")
            ]
            saveCategories()
        }
    }

    func addMemo(_ memo: WatchMemo) {
        memos.insert(memo, at: 0)
        saveMemos()
    }

    func deleteMemo(_ memo: WatchMemo) {
        memos.removeAll { $0.id == memo.id }
        saveMemos()
    }

    func updateFromPhone(memos: [WatchMemo], categories: [WatchCategory]) {
        self.memos = memos
        self.categories = categories
        saveMemos()
        saveCategories()
    }

    private func loadData() {
        loadMemos()
        loadCategories()
    }

    private func loadMemos() {
        if let data = userDefaults.data(forKey: memosKey),
           let decoded = try? JSONDecoder().decode([WatchMemo].self, from: data) {
            memos = decoded
        }
    }

    private func loadCategories() {
        if let data = userDefaults.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([WatchCategory].self, from: data) {
            categories = decoded
        }
    }

    private func saveMemos() {
        if let encoded = try? JSONEncoder().encode(memos) {
            userDefaults.set(encoded, forKey: memosKey)
        }
    }

    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            userDefaults.set(encoded, forKey: categoriesKey)
        }
    }
}