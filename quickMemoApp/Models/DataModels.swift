import Foundation

// MARK: - Core Data Models
struct QuickMemo: Identifiable, Codable {
    let id: UUID
    var content: String
    var primaryCategory: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var calendarEventId: String?
    
    init(content: String, primaryCategory: String, tags: [String] = []) {
        self.id = UUID()
        self.content = content
        self.primaryCategory = primaryCategory
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.calendarEventId = nil
    }
    
    init(id: UUID, content: String, primaryCategory: String, tags: [String], createdAt: Date, updatedAt: Date, calendarEventId: String?) {
        self.id = id
        self.content = content
        self.primaryCategory = primaryCategory
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.calendarEventId = calendarEventId
    }
}

struct Category: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var order: Int
    var defaultTags: [String]
    
    init(name: String, icon: String, color: String, order: Int, defaultTags: [String]) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.order = order
        self.defaultTags = defaultTags
    }
    
    init(id: UUID, name: String, icon: String, color: String, order: Int, defaultTags: [String]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.order = order
        self.defaultTags = defaultTags
    }
}