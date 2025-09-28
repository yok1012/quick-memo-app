import Foundation

// Watch用の軽量データモデル
struct WatchMemo: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var category: String
    var createdAt: Date
    var tags: [String]

    init(id: UUID = UUID(), title: String = "", content: String, category: String, createdAt: Date = Date(), tags: [String] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, category, createdAt, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(category, forKey: .category)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(tags, forKey: .tags)
    }
}

struct WatchCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var defaultTags: [String]
    var baseKey: String?

    init(id: UUID = UUID(), name: String, icon: String, color: String, defaultTags: [String] = [], baseKey: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.defaultTags = defaultTags
        self.baseKey = baseKey
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, defaultTags, baseKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        defaultTags = try container.decodeIfPresent([String].self, forKey: .defaultTags) ?? []
        baseKey = try container.decodeIfPresent(String.self, forKey: .baseKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(defaultTags, forKey: .defaultTags)
        try container.encodeIfPresent(baseKey, forKey: .baseKey)
    }
}
