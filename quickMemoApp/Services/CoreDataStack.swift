import Foundation
import CoreData

class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "QuickMemoApp")
        
        // CloudKit設定
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // CloudKit同期の設定
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // CloudKitコンテナの設定
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.yourcompany.quickMemoApp"
        )
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: - Memo Operations
    
    func fetchMemos() -> [QuickMemo] {
        let request: NSFetchRequest<QuickMemoEntity> = QuickMemoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QuickMemoEntity.createdAt, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toQuickMemo() }
        } catch {
            print("Error fetching memos: \(error)")
            return []
        }
    }
    
    func saveMemo(_ memo: QuickMemo) {
        let request: NSFetchRequest<QuickMemoEntity> = QuickMemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", memo.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            let entity: QuickMemoEntity
            
            if let existingEntity = results.first {
                entity = existingEntity
            } else {
                entity = QuickMemoEntity(context: context)
            }
            
            entity.update(from: memo)
            save()
        } catch {
            print("Error saving memo: \(error)")
        }
    }
    
    func deleteMemo(id: UUID) {
        let request: NSFetchRequest<QuickMemoEntity> = QuickMemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let entity = results.first {
                context.delete(entity)
                save()
            }
        } catch {
            print("Error deleting memo: \(error)")
        }
    }
    
    // MARK: - Category Operations
    
    func fetchCategories() -> [Category] {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CategoryEntity.order, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toCategory() }
        } catch {
            print("Error fetching categories: \(error)")
            return []
        }
    }
    
    func saveCategory(_ category: Category) {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            let entity: CategoryEntity
            
            if let existingEntity = results.first {
                entity = existingEntity
            } else {
                entity = CategoryEntity(context: context)
            }
            
            entity.update(from: category)
            save()
        } catch {
            print("Error saving category: \(error)")
        }
    }
    
    func initializeDefaultCategories() {
        let existingCategories = fetchCategories()
        if existingCategories.isEmpty {
            let defaultCategories = [
                Category(name: "仕事", icon: "briefcase", color: "#007AFF", order: 0, defaultTags: ["会議", "タスク", "締切", "アイデア"]),
                Category(name: "プライベート", icon: "house", color: "#34C759", order: 1, defaultTags: ["買い物", "予定", "思い出", "健康"]),
                Category(name: "アイデア", icon: "lightbulb", color: "#FF9500", order: 2, defaultTags: ["ビジネス", "創作", "改善", "メモ"]),
                Category(name: "人物", icon: "person", color: "#AF52DE", order: 3, defaultTags: ["連絡先", "会話", "約束", "関係"]),
                Category(name: "その他", icon: "folder", color: "#8E8E93", order: 4, defaultTags: ["雑記", "一時", "分類待ち", "保留"])
            ]
            
            for category in defaultCategories {
                saveCategory(category)
            }
        }
    }
}