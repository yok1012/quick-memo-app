import Foundation
import CoreData

@objc(QuickMemoEntity)
public class QuickMemoEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var primaryCategory: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var calendarEventId: String?
    @NSManaged public var category: CategoryEntity?
}

@objc(CategoryEntity)
public class CategoryEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var icon: String?
    @NSManaged public var color: String?
    @NSManaged public var order: Int32
    @NSManaged public var defaultTags: [String]?
    @NSManaged public var memos: NSSet?
}

extension QuickMemoEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<QuickMemoEntity> {
        return NSFetchRequest<QuickMemoEntity>(entityName: "QuickMemo")
    }
    
    func toQuickMemo() -> QuickMemo {
        return QuickMemo(
            id: id ?? UUID(),
            content: content ?? "",
            primaryCategory: primaryCategory ?? "その他",
            tags: tags ?? [],
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            calendarEventId: calendarEventId
        )
    }
    
    func update(from memo: QuickMemo) {
        self.id = memo.id
        self.content = memo.content
        self.primaryCategory = memo.primaryCategory
        self.tags = memo.tags
        self.createdAt = memo.createdAt
        self.updatedAt = memo.updatedAt
        self.calendarEventId = memo.calendarEventId
    }
}

extension CategoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CategoryEntity> {
        return NSFetchRequest<CategoryEntity>(entityName: "Category")
    }
    
    func toCategory() -> Category {
        return Category(
            id: id ?? UUID(),
            name: name ?? "",
            icon: icon ?? "folder",
            color: color ?? "#8E8E93",
            order: Int(order),
            defaultTags: defaultTags ?? []
        )
    }
    
    func update(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
        self.color = category.color
        self.order = Int32(category.order)
        self.defaultTags = category.defaultTags
    }
}