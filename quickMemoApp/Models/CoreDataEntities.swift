import Foundation
import CoreData

// MARK: - QuickMemoEntity

@objc(QuickMemoEntity)
public class QuickMemoEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String
    @NSManaged public var primaryCategory: String
    @NSManaged public var tags: NSObject?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var durationMinutes: Int32
    @NSManaged public var calendarEventId: String?

    func toQuickMemo() -> QuickMemo {
        let tagsArray = (tags as? [String]) ?? []
        return QuickMemo(
            id: id ?? UUID(),
            title: title ?? "",
            content: content,
            primaryCategory: primaryCategory,
            tags: tagsArray,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            calendarEventId: calendarEventId,
            durationMinutes: Int(durationMinutes)
        )
    }

    func update(from memo: QuickMemo) {
        self.id = memo.id
        self.title = memo.title.isEmpty ? nil : memo.title
        self.content = memo.content
        self.primaryCategory = memo.primaryCategory
        self.tags = memo.tags.isEmpty ? nil : memo.tags as NSObject
        self.createdAt = memo.createdAt
        self.updatedAt = memo.updatedAt
        self.durationMinutes = Int32(memo.durationMinutes)
        self.calendarEventId = memo.calendarEventId
    }
}

// MARK: - CategoryEntity

@objc(CategoryEntity)
public class CategoryEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var icon: String
    @NSManaged public var color: String
    @NSManaged public var order: Int32
    @NSManaged public var defaultTags: NSObject?

    func toCategory() -> Category {
        let tagsArray = (defaultTags as? [String]) ?? []
        return Category(
            id: id ?? UUID(),
            name: name,
            icon: icon,
            color: color,
            order: Int(order),
            defaultTags: tagsArray
        )
    }

    func update(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
        self.color = category.color
        self.order = Int32(category.order)
        self.defaultTags = category.defaultTags.isEmpty ? nil : category.defaultTags as NSObject
    }
}

// MARK: - Core Data Fetch Request Extensions

extension QuickMemoEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<QuickMemoEntity> {
        return NSFetchRequest<QuickMemoEntity>(entityName: "QuickMemoEntity")
    }
}

extension CategoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CategoryEntity> {
        return NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
    }
}