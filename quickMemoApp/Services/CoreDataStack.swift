import Foundation
import CoreData

class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    private func managedObjectModel() -> NSManagedObjectModel {
        guard let modelURL = Bundle.main.url(forResource: "QuickMemoApp", withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create managed object model")
        }
        return managedObjectModel
    }

    lazy var persistentContainer: NSPersistentContainer = {
        // 一時的に通常のNSPersistentContainerを使用（CloudKit同期を無効化）
        let container = NSPersistentContainer(name: "QuickMemoApp", managedObjectModel: self.managedObjectModel())

        // ローカルストレージのみの設定
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        // 履歴トラッキングを有効化（将来のCloudKit統合のため）
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
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
        }
    }
    
    func initializeDefaultCategories() {
        let existingCategories = fetchCategories()
        if existingCategories.isEmpty {
            let defaultCategories = LocalizedCategories.getDefaultCategories().enumerated().map { index, info in
                Category(
                    name: info.name,
                    icon: LocalizedCategories.iconName(for: info.key),
                    color: info.color,
                    order: index,
                    defaultTags: LocalizedCategories.defaultTagKeys(for: info.key).map { $0.localized },
                    isDefault: true,
                    baseKey: info.key
                )
            }

            let otherCategory = Category(
                name: LocalizedCategories.localizedName(for: "other"),
                icon: LocalizedCategories.iconName(for: "other"),
                color: LocalizedCategories.colorHex(for: "other"),
                order: defaultCategories.count,
                defaultTags: LocalizedCategories.defaultTagKeys(for: "other").map { $0.localized },
                isDefault: true,
                baseKey: "other"
            )

            for category in defaultCategories + [otherCategory] {
                saveCategory(category)
            }
        }
    }
}
