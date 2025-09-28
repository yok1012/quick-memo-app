import Foundation

// MARK: - Core Data Models
struct QuickMemo: Identifiable, Codable {
    let id: UUID
    var title: String  // タイトルフィールドを追加
    var content: String
    var primaryCategory: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var calendarEventId: String?
    var durationMinutes: Int  // カレンダーイベントの期間（分）

    init(title: String = "", content: String, primaryCategory: String, tags: [String] = [], durationMinutes: Int = 30) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.primaryCategory = primaryCategory
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.calendarEventId = nil
        self.durationMinutes = durationMinutes
    }

    init(id: UUID, title: String = "", content: String, primaryCategory: String, tags: [String], createdAt: Date, updatedAt: Date, calendarEventId: String?, durationMinutes: Int = 30) {
        self.id = id
        self.title = title
        self.content = content
        self.primaryCategory = primaryCategory
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.calendarEventId = calendarEventId
        self.durationMinutes = durationMinutes
    }
    
    // 既存データの互換性のためのカスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        // titleが存在しない古いデータの場合は空文字をデフォルトとする
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decode(String.self, forKey: .content)
        primaryCategory = try container.decode(String.self, forKey: .primaryCategory)
        tags = try container.decode([String].self, forKey: .tags)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        calendarEventId = try container.decodeIfPresent(String.self, forKey: .calendarEventId)
        // durationMinutesが存在しない古いデータの場合は30分をデフォルトとする
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 30
    }
}

struct Category: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var order: Int
    var defaultTags: [String]
    var isDefault: Bool = false  // Track if this is a default category
    var baseKey: String? = nil   // Base localization key for default categories

    init(name: String, icon: String, color: String, order: Int, defaultTags: [String], isDefault: Bool = false, baseKey: String? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.order = order
        self.defaultTags = defaultTags
        self.isDefault = isDefault
        self.baseKey = baseKey
    }

    init(id: UUID, name: String, icon: String, color: String, order: Int, defaultTags: [String], isDefault: Bool = false, baseKey: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.order = order
        self.defaultTags = defaultTags
        self.isDefault = isDefault
        self.baseKey = baseKey
    }

    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        order = try container.decode(Int.self, forKey: .order)
        defaultTags = try container.decode([String].self, forKey: .defaultTags)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        baseKey = try container.decodeIfPresent(String.self, forKey: .baseKey)
    }
}