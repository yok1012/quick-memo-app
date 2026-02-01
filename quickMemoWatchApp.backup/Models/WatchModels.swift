import Foundation

// Watch用の軽量データモデル
struct WatchMemo: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var category: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String = "", content: String, category: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
    }
}

struct WatchCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var color: String

    init(id: UUID = UUID(), name: String, icon: String, color: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
}

// Watch用のデータマネージャー
class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()

    @Published var memos: [WatchMemo] = []
    @Published var categories: [WatchCategory] = []

    private let memosKey = "watch_memos"
    private let categoriesKey = "watch_categories"

    private init() {
        loadData()
        initializeDefaultCategories()
    }

    private func loadData() {
        loadMemos()
        loadCategories()
    }

    private func loadMemos() {
        if let data = UserDefaults.standard.data(forKey: memosKey),
           let decodedMemos = try? JSONDecoder().decode([WatchMemo].self, from: data) {
            memos = decodedMemos
        }
    }

    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decodedCategories = try? JSONDecoder().decode([WatchCategory].self, from: data) {
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

    func addMemo(_ memo: WatchMemo) {
        memos.append(memo)
        saveMemos()
    }

    func deleteMemo(id: UUID) {
        memos.removeAll { $0.id == id }
        saveMemos()
    }

    func updateFromPhone(memos: [WatchMemo], categories: [WatchCategory]) {
        self.memos = memos
        self.categories = categories
        saveMemos()
        saveCategories()
    }

    private func initializeDefaultCategories() {
        if categories.isEmpty {
            categories = [
                WatchCategory(name: "仕事", icon: "briefcase", color: "#007AFF"),
                WatchCategory(name: "プライベート", icon: "house", color: "#34C759"),
                WatchCategory(name: "アイデア", icon: "lightbulb", color: "#FF9500"),
                WatchCategory(name: "その他", icon: "folder", color: "#8E8E93")
            ]
            saveCategories()
        }
    }

    func getCategory(named name: String) -> WatchCategory? {
        return categories.first { $0.name == name }
    }
}