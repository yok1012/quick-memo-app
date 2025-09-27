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