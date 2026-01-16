import Foundation
import SwiftUI
import CoreData
import os.log
#if canImport(WidgetKit)
import WidgetKit
#endif

// DataManager専用のログカテゴリ
private let dataManagerLog = OSLog(subsystem: "yokAppDev.quickMemoApp", category: "DataManager")

@MainActor
class DataManager: ObservableObject {
    
    static let shared = DataManager()
    
    @Published var memos: [QuickMemo] = []
    @Published var categories: [Category] = [] {
        didSet {
            print("📱 Categories updated: \(categories.count) items")
        }
    }
    @Published var archivedMemos: [ArchivedMemo] = []  // 削除履歴

    private let purchaseManager = PurchaseManager.shared
    private let coreDataStack = CoreDataStack.shared
    private var iCloudSyncEnabled = false

    /// iCloud復元処理が完了したかどうかを示すフラグ
    /// このフラグがfalseの間は、diagnoseAndRepairCategoriesでデフォルトカテゴリーを作成しない
    @Published private(set) var isCloudRestoreComplete = false

    private let memosKey = "quick_memos"
    private let categoriesKey = "categories"
    private let categoriesBackupKey = "categories_backup"  // カテゴリーのバックアップ用
    private let widgetCategoriesKey = "widget_categories"
    private let isProVersionKey = "is_pro_version"
    private let archivedMemosKey = "archived_memos"  // 削除履歴の保存キー
    private let firstLaunchCompletedKey = "first_launch_completed_v2"  // v2に変更して新しい動作を保証
    private let dataMigratedKey = "data_migrated_v1"  // データマイグレーション完了フラグ
    private let appVersionKey = "app_version"  // アプリバージョン管理用

    // App Group identifier for widget data sharing
    private let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
    private var userDefaults: UserDefaults

    init() {
        os_log("🔴 DataManager init() called", log: dataManagerLog, type: .info)
        print("🔴 =====================================")
        print("🔴 DataManager init() called")
        print("🔴 =====================================")

        // Use App Group's UserDefaults for data sharing with widget
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.userDefaults = groupDefaults
            os_log("✅ Using App Group UserDefaults: %{public}@", log: dataManagerLog, type: .info, appGroupIdentifier)
            print("✅ Using App Group UserDefaults: \(appGroupIdentifier)")
        } else {
            // Fallback to standard UserDefaults if App Group is not available
            self.userDefaults = UserDefaults.standard
            os_log("⚠️ Falling back to standard UserDefaults", log: dataManagerLog, type: .info)
            print("⚠️ Falling back to standard UserDefaults")
        }

        // 🚨 重要: データマイグレーションを最初に実行
        // App Groups entitlement追加により、旧データが別の場所にある可能性
        migrateDataFromOldLocations()

        // カテゴリーを読み込む
        loadCategories()
        os_log("📊 After loadCategories: %d categories", log: dataManagerLog, type: .info, categories.count)
        print("📊 After load: \(categories.count) categories")

        // メモを読み込む
        loadMemos()
        os_log("📊 After loadMemos: %d memos", log: dataManagerLog, type: .info, memos.count)
        print("📊 After load: \(memos.count) memos")

        // 削除履歴を読み込む
        loadArchivedMemos()

        // セットアップ（iCloud復元は非同期で後から実行される）
        // 🚨 注意: この時点ではまだローカルデータのみ。iCloud復元は非同期で実行される
        os_log("📋 Starting iCloud sync setup (async)...", log: dataManagerLog, type: .info)
        setupiCloudSyncAndRestore()
        setupLanguageObserver()

        // 最終状態をログ（iCloud復元はまだ完了していない可能性あり）
        os_log("📋 DataManager init complete (iCloud restore pending). categories=%d, memos=%d", log: dataManagerLog, type: .info, categories.count, memos.count)
        print("📋 DataManager initialization complete")
        print("📋 Final state: \(categories.count) categories, \(memos.count) memos")
        print("🔴 =====================================")
    }

    // MARK: - データマイグレーション（旧データの復元）

    /// 旧バージョンのデータを探して新しい場所にマイグレーションする
    private func migrateDataFromOldLocations() {
        // 既にマイグレーション済みならスキップ
        if userDefaults.bool(forKey: dataMigratedKey) {
            print("✅ Data migration already completed")
            return
        }

        print("🔄 Starting data migration from old locations...")

        var migrated = false

        // 1. 標準UserDefaultsからマイグレーション
        migrated = migrateFromStandardUserDefaults() || migrated

        // 2. App Group (entitlement追加前の擬似的な場所) からマイグレーション
        // Note: entitlement追加前も UserDefaults(suiteName:) は動作するが、
        // 実際のApp Groupコンテナとは別の場所にデータが保存されている可能性がある

        // マイグレーション完了フラグを設定
        if migrated {
            userDefaults.set(true, forKey: dataMigratedKey)
            userDefaults.synchronize()
            print("✅ Data migration completed")
        } else {
            print("ℹ️ No legacy data found to migrate")
        }
    }

    /// 標準UserDefaultsからデータをマイグレーション
    private func migrateFromStandardUserDefaults() -> Bool {
        let standard = UserDefaults.standard
        var migrated = false

        // App Groupと標準UserDefaultsが同じインスタンスなら何もしない
        if userDefaults === standard {
            return false
        }

        print("🔍 Checking standard UserDefaults for legacy data...")

        // カテゴリーのマイグレーション
        if userDefaults.data(forKey: categoriesKey) == nil,
           let legacyCategoriesData = standard.data(forKey: categoriesKey) {
            print("📦 Found legacy categories in standard UserDefaults")
            if let legacyCategories = try? JSONDecoder().decode([Category].self, from: legacyCategoriesData),
               !legacyCategories.isEmpty {
                userDefaults.set(legacyCategoriesData, forKey: categoriesKey)
                userDefaults.set(legacyCategoriesData, forKey: categoriesBackupKey)
                print("✅ Migrated \(legacyCategories.count) categories")
                migrated = true
            }
        }

        // メモのマイグレーション
        if userDefaults.data(forKey: memosKey) == nil,
           let legacyMemosData = standard.data(forKey: memosKey) {
            print("📦 Found legacy memos in standard UserDefaults")
            if let legacyMemos = try? JSONDecoder().decode([QuickMemo].self, from: legacyMemosData),
               !legacyMemos.isEmpty {
                userDefaults.set(legacyMemosData, forKey: memosKey)
                print("✅ Migrated \(legacyMemos.count) memos")
                migrated = true
            }
        }

        // 削除履歴のマイグレーション
        if userDefaults.data(forKey: archivedMemosKey) == nil,
           let legacyArchivedData = standard.data(forKey: archivedMemosKey) {
            print("📦 Found legacy archived memos in standard UserDefaults")
            userDefaults.set(legacyArchivedData, forKey: archivedMemosKey)
            migrated = true
        }

        // ウィジェット設定のマイグレーション
        if userDefaults.data(forKey: widgetCategoriesKey) == nil,
           let legacyWidgetData = standard.data(forKey: widgetCategoriesKey) {
            userDefaults.set(legacyWidgetData, forKey: widgetCategoriesKey)
            migrated = true
        }

        // Pro版状態のマイグレーション
        if !userDefaults.bool(forKey: isProVersionKey) && standard.bool(forKey: isProVersionKey) {
            userDefaults.set(true, forKey: isProVersionKey)
            migrated = true
        }

        if migrated {
            userDefaults.synchronize()
        }

        return migrated
    }

    /// レガシーデータが存在するかチェック
    private func checkForLegacyData() -> Bool {
        let standard = UserDefaults.standard

        // 標準UserDefaultsにデータがあるか確認
        if let categoriesData = standard.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode([Category].self, from: categoriesData),
           !categories.isEmpty {
            print("⚠️ Found legacy categories in standard UserDefaults!")
            // マイグレーションを再実行
            _ = migrateFromStandardUserDefaults()
            return true
        }

        if let memosData = standard.data(forKey: memosKey),
           let memos = try? JSONDecoder().decode([QuickMemo].self, from: memosData),
           !memos.isEmpty {
            print("⚠️ Found legacy memos in standard UserDefaults!")
            _ = migrateFromStandardUserDefaults()
            return true
        }

        return false
    }

    // MARK: - 手動データ復元機能（設定画面から呼び出し可能）

    /// 全ての可能な場所からデータを探して復元を試みる（ユーザーが手動で実行可能）
    func attemptFullDataRecovery() -> (categories: Int, memos: Int) {
        print("🚨 Attempting full data recovery...")
        print("🔍 Current state: \(categories.count) categories, \(memos.count) memos")

        var recoveredCategories = 0
        var recoveredMemos = 0

        // 復旧対象のUserDefaultsインスタンスを複数チェック
        var userDefaultsToCheck: [(name: String, defaults: UserDefaults)] = []

        // 1. 標準UserDefaults
        userDefaultsToCheck.append(("Standard UserDefaults", UserDefaults.standard))

        // 2. App Group UserDefaults（異なるsuite名のバリエーション）
        let possibleSuiteNames = [
            "group.yokAppDev.quickMemoApp",
            "yokAppDev.quickMemoApp",
            "com.yokAppDev.quickMemoApp"
        ]

        for suiteName in possibleSuiteNames {
            if let ud = UserDefaults(suiteName: suiteName) {
                userDefaultsToCheck.append(("Suite: \(suiteName)", ud))
            }
        }

        // 各UserDefaultsインスタンスをチェック
        for (name, defaults) in userDefaultsToCheck {
            defaults.synchronize()

            // カテゴリーの復元を試みる（現在のカテゴリーより多い場合のみ）
            if let data = defaults.data(forKey: categoriesKey),
               let recovered = try? JSONDecoder().decode([Category].self, from: data),
               !recovered.isEmpty,
               recovered.count > categories.count {
                print("✅ Found \(recovered.count) categories in \(name)")
                categories = recovered
                saveCategories()
                recoveredCategories = recovered.count
            }

            // メモの復元を試みる（現在のメモより多い場合のみ）
            if let data = defaults.data(forKey: memosKey),
               let recovered = try? JSONDecoder().decode([QuickMemo].self, from: data),
               !recovered.isEmpty,
               recovered.count > memos.count {
                print("✅ Found \(recovered.count) memos in \(name)")
                memos = recovered
                saveMemos()
                recoveredMemos = recovered.count
            }

            // バックアップキーもチェック
            if let data = defaults.data(forKey: categoriesBackupKey),
               let recovered = try? JSONDecoder().decode([Category].self, from: data),
               !recovered.isEmpty,
               recovered.count > categories.count {
                print("✅ Found \(recovered.count) categories in backup of \(name)")
                categories = recovered
                saveCategories()
                recoveredCategories = recovered.count
            }
        }

        // 削除履歴からもメモを探す
        if memos.isEmpty {
            loadArchivedMemos()
            if !archivedMemos.isEmpty {
                print("📦 Found \(archivedMemos.count) archived memos, restoring...")
                for archived in archivedMemos {
                    memos.append(archived.originalMemo)
                }
                saveMemos()
                recoveredMemos = memos.count
            }
        }

        // メモからカテゴリーを再構築
        if categories.isEmpty && !memos.isEmpty {
            reconstructCategoriesFromMemos()
            recoveredCategories = categories.count
        }

        print("📋 Recovery complete: \(recoveredCategories) categories, \(recoveredMemos) memos")

        return (recoveredCategories, recoveredMemos)
    }

    /// マイグレーションフラグをリセット（デバッグ用）
    func resetMigrationFlag() {
        userDefaults.removeObject(forKey: dataMigratedKey)
        userDefaults.synchronize()
        print("🔄 Migration flag reset")
    }

    /// カテゴリーデータの復元を試みる
    private func attemptCategoryRecovery() {
        print("🔧 Attempting category recovery...")

        // バックアップからの復元を試みる
        if let backupData = userDefaults.data(forKey: categoriesBackupKey) {
            do {
                let recoveredCategories = try JSONDecoder().decode([Category].self, from: backupData)
                if !recoveredCategories.isEmpty {
                    print("✅ Recovered \(recoveredCategories.count) categories from backup")
                    categories = recoveredCategories
                    saveCategories()  // メインのキーに保存
                    return
                }
            } catch {
                print("❌ Failed to recover from backup: \(error)")
            }
        }

        // 標準UserDefaultsからの復元を試みる（App Groupが使えない場合のフォールバック）
        if userDefaults !== UserDefaults.standard {
            if let standardData = UserDefaults.standard.data(forKey: categoriesKey) {
                do {
                    let recoveredCategories = try JSONDecoder().decode([Category].self, from: standardData)
                    if !recoveredCategories.isEmpty {
                        print("✅ Recovered \(recoveredCategories.count) categories from standard UserDefaults")
                        categories = recoveredCategories
                        saveCategories()  // App Groupに保存
                        return
                    }
                } catch {
                    print("❌ Failed to recover from standard UserDefaults: \(error)")
                }
            }
        }

        // 復元できない場合は、メモからカテゴリーを推測して再作成
        print("⚠️ No backup available, reconstructing categories from memos...")
        reconstructCategoriesFromMemos()
    }

    /// メモデータからカテゴリーを再構築する
    private func reconstructCategoriesFromMemos() {
        // まずメモを読み込む
        if let data = userDefaults.data(forKey: memosKey),
           let decodedMemos = try? JSONDecoder().decode([QuickMemo].self, from: data) {

            // メモで使用されているカテゴリー名を収集
            let usedCategoryNames = Set(decodedMemos.map { $0.primaryCategory })
            print("📝 Found \(usedCategoryNames.count) category names in memos: \(usedCategoryNames)")

            var reconstructedCategories: [Category] = []
            var order = 0

            // デフォルトカテゴリーを先に作成
            let defaultKeys = ["work", "personal", "idea", "people", "other"]
            for key in defaultKeys {
                let localizedName = LocalizedCategories.localizedName(for: key)
                let category = Category(
                    name: localizedName,
                    icon: LocalizedCategories.iconName(for: key),
                    color: LocalizedCategories.colorHex(for: key),
                    order: order,
                    defaultTags: LocalizedCategories.defaultTagKeys(for: key).map { $0.localized },
                    isDefault: true,
                    baseKey: key
                )
                reconstructedCategories.append(category)
                order += 1
            }

            // メモに存在するがデフォルトにないカテゴリーを追加
            let defaultNames = Set(reconstructedCategories.map { $0.name })
            for categoryName in usedCategoryNames {
                if !defaultNames.contains(categoryName) && LocalizedCategories.baseKey(forLocalizedName: categoryName) == nil {
                    let category = Category(
                        name: categoryName,
                        icon: "folder",
                        color: "#8E8E93",
                        order: order,
                        defaultTags: [],
                        isDefault: false,
                        baseKey: nil
                    )
                    reconstructedCategories.append(category)
                    order += 1
                    print("📁 Reconstructed custom category: \(categoryName)")
                }
            }

            categories = reconstructedCategories
            saveCategories()
            print("✅ Reconstructed \(categories.count) categories")
        } else {
            // メモもない場合はデフォルトを作成
            print("⚠️ No memos found, creating default categories")
            createDefaultCategories()
        }
    }
    
    // MARK: - 簡略化された読み込み処理
    
    private func loadCategories() {
        print("🔍 loadCategories() - attempting to load...")

        // メインのキーから読み込みを試みる
        if let data = userDefaults.data(forKey: categoriesKey) {
            if let loadedCategories = decodeCategories(from: data) {
                categories = loadedCategories
                print("✅ Loaded \(categories.count) categories from main storage")
                return
            } else {
                print("⚠️ Failed to decode from main storage, trying backup...")
            }
        } else {
            print("⚠️ No categories data found in main storage")
        }

        // バックアップから読み込みを試みる
        if let backupData = userDefaults.data(forKey: categoriesBackupKey) {
            if let loadedCategories = decodeCategories(from: backupData) {
                categories = loadedCategories
                print("✅ Loaded \(categories.count) categories from backup")
                // メインのキーに復元
                saveCategories()
                return
            } else {
                print("⚠️ Failed to decode from backup")
            }
        }

        // 両方失敗した場合は空配列
        print("❌ No valid category data found")
        categories = []
    }

    /// カテゴリーデータをデコードするヘルパー
    private func decodeCategories(from data: Data) -> [Category]? {
        do {
            var decodedCategories = try JSONDecoder().decode([Category].self, from: data)
            normalizeDefaultCategoryMetadata(for: &decodedCategories)

            print("📊 Decoded \(decodedCategories.count) categories")

            // Free版の制限を適用（ただし読み込み時はデータを保護）
            // 注意: Pro状態が確定していない場合も全データを保持する
            if !purchaseManager.isProVersion && decodedCategories.count > 5 {
                print("⚠️ Free user with \(decodedCategories.count) categories (showing first 5)")
                // UIでは5つまで表示するが、データは全て保持
                return decodedCategories
            }

            return decodedCategories
        } catch {
            print("❌ Decode error: \(error)")
            return nil
        }
    }
    
    private func loadMemos() {
        if let data = userDefaults.data(forKey: memosKey),
           let decodedMemos = try? JSONDecoder().decode([QuickMemo].self, from: data) {
            memos = decodedMemos
            print("✅ Loaded \(memos.count) memos")
        }
    }
    
    private func loadArchivedMemos() {
        if let data = userDefaults.data(forKey: archivedMemosKey),
           let decodedArchivedMemos = try? JSONDecoder().decode([ArchivedMemo].self, from: data) {
            archivedMemos = decodedArchivedMemos
        }
    }

    private func saveArchivedMemos() {
        if let data = try? JSONEncoder().encode(archivedMemos) {
            userDefaults.set(data, forKey: archivedMemosKey)
        }
    }
    
    private func saveMemos() {
        // Always save to UserDefaults for widgets
        if let data = try? JSONEncoder().encode(memos) {
            userDefaults.set(data, forKey: memosKey)
            // Notify widget to update
            notifyWidgetUpdate()
        }

        // Also save to Core Data if Pro version
        if iCloudSyncEnabled {
            Task {
                await saveMemosToCoreData()
            }
        }
    }

    private func saveMemosToCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            for memo in memos {
                coreDataStack.saveMemo(memo)
            }
        }
    }
    
    func saveCategories() {
        // Always save to UserDefaults for widgets
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: categoriesKey)

            // バックアップも保存（データ消失対策）
            userDefaults.set(data, forKey: categoriesBackupKey)

            userDefaults.synchronize()

            print("💾 Saved \(categories.count) categories (with backup)")

            // マイグレーション済みフラグを確実に設定
            if !categories.isEmpty && !userDefaults.bool(forKey: dataMigratedKey) {
                userDefaults.set(true, forKey: dataMigratedKey)
                userDefaults.synchronize()
            }

            // Notify widget to update
            notifyWidgetUpdate()
        } catch {
            print("❌ Failed to encode categories: \(error)")
        }

        // Also save to Core Data if Pro version
        if iCloudSyncEnabled {
            Task {
                await saveCategoriesToCoreData()
            }
        }
    }

    private func saveCategoriesToCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            for category in categories {
                coreDataStack.saveCategory(category)
            }
        }
    }

    private func notifyWidgetUpdate() {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    
    // MARK: - iCloud Sync Setup

    private func setupiCloudSyncAndRestore() {
        Task { @MainActor in
            os_log("🔄 setupiCloudSyncAndRestore: Starting...", log: dataManagerLog, type: .info)
            print("🔄 setupiCloudSyncAndRestore: Starting...")

            // 🚨 重要: PurchaseManagerの読み込み完了を待機
            // これにより、StoreKitが購入状態を確認してからiCloud復元を判断する
            os_log("⏳ Waiting for PurchaseManager to complete loading...", log: dataManagerLog, type: .info)
            await purchaseManager.waitForLoadingComplete()
            os_log("✅ PurchaseManager loading complete", log: dataManagerLog, type: .info)

            // Pro版ユーザーのみiCloud同期を有効化
            iCloudSyncEnabled = purchaseManager.isProVersion
            os_log("📊 iCloudSyncEnabled=%{public}d, isProVersion=%{public}d", log: dataManagerLog, type: .info, iCloudSyncEnabled ? 1 : 0, purchaseManager.isProVersion ? 1 : 0)
            print("📊 iCloudSyncEnabled = \(iCloudSyncEnabled) (isProVersion = \(purchaseManager.isProVersion))")

            // 🚨 重要: アプリ再インストール時のiCloud復元処理
            // データが空の場合、デフォルトカテゴリー作成前にiCloudから復元を試みる
            os_log("📊 Current data: memos=%d, categories=%d", log: dataManagerLog, type: .info, memos.count, categories.count)

            if memos.isEmpty && categories.isEmpty {
                os_log("📭 No local data found, checking for iCloud backup...", log: dataManagerLog, type: .info)
                print("📭 No local data found, checking for iCloud backup...")

                // まずiCloudが利用可能かチェック（Pro状態に関係なく）
                let iCloudAvailable = await CloudKitManager.shared.isiCloudAvailable()
                os_log("☁️ iCloud available: %{public}d", log: dataManagerLog, type: .info, iCloudAvailable ? 1 : 0)
                print("☁️ iCloud available: \(iCloudAvailable)")

                if iCloudAvailable {
                    // まずバックアップの存在を確認
                    os_log("🔍 Checking if backup exists...", log: dataManagerLog, type: .info)
                    if let backupInfo = await CloudKitManager.shared.getBackupInfo() {
                        os_log("📦 Backup exists! memos=%d, categories=%d, date=%{public}@", log: dataManagerLog, type: .info, backupInfo.memosCount, backupInfo.categoriesCount, backupInfo.date?.description ?? "unknown")
                    } else {
                        os_log("⚠️ No backup info found", log: dataManagerLog, type: .info)
                    }

                    // iCloudにバックアップがあるかチェック（Pro状態に関係なく試みる）
                    // バックアップがあるということは、以前Pro版だったということ
                    os_log("🔍 Attempting iCloud restore...", log: dataManagerLog, type: .info)
                    print("🔍 Checking for existing iCloud backup...")
                    let restored = await attemptCloudRestore()

                    if restored {
                        os_log("✅ Data restored from iCloud! memos=%d, categories=%d", log: dataManagerLog, type: .info, memos.count, categories.count)
                        print("✅ Data restored from iCloud!")
                        // 復元成功したらiCloud同期を有効化（Pro版として扱う）
                        iCloudSyncEnabled = true
                    } else {
                        // 復元できなかった場合のみデフォルトカテゴリーを作成
                        os_log("📭 No iCloud backup found, creating default categories...", log: dataManagerLog, type: .info)
                        print("📭 No iCloud backup found, creating default categories...")
                        createDefaultCategories()
                    }
                } else {
                    os_log("ℹ️ iCloud not available, creating default categories...", log: dataManagerLog, type: .info)
                    print("ℹ️ iCloud not available, creating default categories...")
                    createDefaultCategories()
                }
            } else if categories.isEmpty && !memos.isEmpty {
                // メモはあるがカテゴリーがない = カテゴリーデータ消失
                os_log("⚠️ Memos exist but categories missing - reconstructing...", log: dataManagerLog, type: .info)
                print("⚠️ Memos exist but categories missing - reconstructing...")
                reconstructCategoriesFromMemos()
            } else {
                os_log("📊 Local data exists: categories=%d, memos=%d", log: dataManagerLog, type: .info, categories.count, memos.count)
                print("📊 Local data exists: \(categories.count) categories, \(memos.count) memos")
                if iCloudSyncEnabled {
                    print("✅ iCloud sync enabled (Pro version)")
                } else {
                    print("ℹ️ iCloud sync disabled (Free version)")
                }
            }

            os_log("🏁 setupiCloudSyncAndRestore complete. Final: memos=%d, categories=%d", log: dataManagerLog, type: .info, memos.count, categories.count)

            // iCloud復元処理完了フラグを設定
            self.isCloudRestoreComplete = true
            os_log("✅ isCloudRestoreComplete = true", log: dataManagerLog, type: .info)
        }

        // Listen for Pro version changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(purchaseStatusChanged),
            name: NSNotification.Name("PurchaseStatusChanged"),
            object: nil
        )

        // Listen for app going to background (auto backup)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        // バックグラウンドに入る時に自動バックアップ
        Task {
            await performAutoBackup()
        }
    }

    /// 自動バックアップを実行（Pro版のみ）
    private func performAutoBackup() async {
        guard iCloudSyncEnabled else { return }

        // 🚨 重要: iCloud復元処理が完了するまでバックアップしない
        guard isCloudRestoreComplete else {
            print("⏳ Auto backup skipped - iCloud restore not complete yet")
            return
        }

        // 🚨 重要: 空データをバックアップしない
        guard !memos.isEmpty || !categories.isEmpty else {
            print("⚠️ Auto backup skipped - no data to backup")
            return
        }

        // 前回のバックアップから1時間以上経過している場合のみ実行
        let lastBackup = UserDefaults.standard.object(forKey: "lastCloudBackupDate") as? Date
        if let lastBackup = lastBackup, Date().timeIntervalSince(lastBackup) < 3600 {
            return
        }

        print("☁️ Performing auto backup to iCloud...")
        _ = await CloudKitManager.shared.backupData(memos: memos, categories: categories)
    }

    /// iCloudからデータを復元する
    /// - Returns: 復元が成功した場合はtrue（メモまたはカテゴリーが1件以上復元された場合）
    private func attemptCloudRestore() async -> Bool {
        os_log("☁️ attemptCloudRestore: Starting...", log: dataManagerLog, type: .info)
        print("☁️ ========================================")
        print("☁️ attemptCloudRestore: Starting iCloud restore...")
        print("☁️ ========================================")

        // 復元前の状態をログ
        os_log("📊 Before restore: memos=%d, categories=%d, isProVersion=%{public}d", log: dataManagerLog, type: .info, memos.count, categories.count, purchaseManager.isProVersion ? 1 : 0)
        print("📊 Current state before restore:")
        print("   - Memos: \(memos.count)")
        print("   - Categories: \(categories.count)")
        print("   - isProVersion: \(purchaseManager.isProVersion)")

        os_log("🌐 Calling CloudKitManager.restoreData()...", log: dataManagerLog, type: .info)

        if let restored = await CloudKitManager.shared.restoreData() {
            var didRestore = false

            os_log("📦 Restore result: memos=%d, categories=%d", log: dataManagerLog, type: .info, restored.memos.count, restored.categories.count)
            print("📦 Restore result received:")
            print("   - Memos in backup: \(restored.memos.count)")
            print("   - Categories in backup: \(restored.categories.count)")

            if !restored.memos.isEmpty {
                memos = restored.memos
                saveMemos()
                os_log("✅ Restored %d memos from iCloud", log: dataManagerLog, type: .info, restored.memos.count)
                print("✅ Restored \(restored.memos.count) memos from iCloud")
                didRestore = true
            }
            if !restored.categories.isEmpty {
                categories = restored.categories
                saveCategories()
                os_log("✅ Restored %d categories from iCloud", log: dataManagerLog, type: .info, restored.categories.count)
                print("✅ Restored \(restored.categories.count) categories from iCloud")
                didRestore = true
            }

            if didRestore {
                os_log("🎉 iCloud restore SUCCESSFUL! Final: memos=%d, categories=%d", log: dataManagerLog, type: .info, memos.count, categories.count)
                print("🎉 ========================================")
                print("🎉 iCloud restore SUCCESSFUL!")
                print("🎉 Final state: \(memos.count) memos, \(categories.count) categories")
                print("🎉 ========================================")

                // 🚨 重要: データは既にmemosとcategoriesに設定済み
                // saveMemos()とsaveCategories()は呼び出し元で既に実行されているが、念のため再度保存
                saveMemos()
                saveCategories()

                // UIを強制更新（複数の方法で確実に）
                self.objectWillChange.send()

                // Notificationを発行してViewを更新
                NotificationCenter.default.post(name: Notification.Name("iCloudRestoreCompleted"), object: nil)
            } else {
                os_log("⚠️ Backup found but no data to restore", log: dataManagerLog, type: .info)
                print("⚠️ Backup found but no data to restore")
            }

            return didRestore
        }

        os_log("❌ iCloud restore FAILED - No backup found", log: dataManagerLog, type: .error)
        print("❌ ========================================")
        print("❌ iCloud restore FAILED - No backup found")
        print("❌ ========================================")
        return false
    }

    /// 手動でiCloudにバックアップ
    func backupToiCloud() async -> Bool {
        guard purchaseManager.isProVersion else {
            print("⚠️ iCloud backup requires Pro version")
            return false
        }

        return await CloudKitManager.shared.backupData(memos: memos, categories: categories)
    }

    /// 手動でiCloudからリストア
    func restoreFromiCloud() async -> (memos: Int, categories: Int) {
        guard purchaseManager.isProVersion else {
            print("⚠️ iCloud restore requires Pro version")
            return (0, 0)
        }

        if let restored = await CloudKitManager.shared.restoreData() {
            var restoredMemos = 0
            var restoredCategories = 0

            if !restored.memos.isEmpty {
                memos = restored.memos
                saveMemos()
                restoredMemos = restored.memos.count
            }
            if !restored.categories.isEmpty {
                categories = restored.categories
                saveCategories()
                restoredCategories = restored.categories.count
            }

            return (restoredMemos, restoredCategories)
        }

        return (0, 0)
    }

    private func setupLanguageObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateCategoryLanguages),
            name: Notification.Name("UpdateCategoryLanguage"),
            object: nil
        )
    }

    @objc private func updateCategoryLanguages() {
        Task { @MainActor in
            // Update default category names based on current language
            for index in categories.indices {
                guard categories[index].isDefault else { continue }

                if categories[index].baseKey == nil {
                    categories[index].baseKey = LocalizedCategories.baseKey(forLocalizedName: categories[index].name)
                }

                guard let baseKey = categories[index].baseKey else { continue }

                let oldName = categories[index].name
                let localizedName = LocalizedCategories.localizedName(for: baseKey)

                categories[index].name = localizedName
                categories[index].icon = LocalizedCategories.iconName(for: baseKey)
                categories[index].color = LocalizedCategories.colorHex(for: baseKey)
                categories[index].defaultTags = LocalizedCategories.defaultTagKeys(for: baseKey).map { $0.localized }

                if oldName != localizedName {
                    updateMemosWithCategoryChange(oldName: oldName, newName: localizedName)
                }
            }
            saveCategories()

            // Force UI refresh
            objectWillChange.send()
        }
    }

    @objc private func purchaseStatusChanged() {
        Task { @MainActor in
            let wasEnabled = iCloudSyncEnabled
            iCloudSyncEnabled = purchaseManager.isProVersion

            if !wasEnabled && iCloudSyncEnabled {
                print("🎉 Upgraded to Pro - enabling iCloud sync")

                // 🚨 重要: iCloud復元処理が完了するまでバックアップしない
                // アプリ再インストール時、StoreKitが購入状態を復元すると通知が発火するが、
                // この時点ではまだiCloudからのデータ復元が完了していない可能性がある。
                // 空データでバックアップすると、有効なバックアップが上書きされてしまう。
                guard isCloudRestoreComplete else {
                    print("⏳ Skipping backup - iCloud restore not complete yet")
                    return
                }

                // 🚨 重要: 空データをバックアップしない
                // データが空の場合はバックアップをスキップ
                guard !memos.isEmpty || !categories.isEmpty else {
                    print("⚠️ Skipping backup - no data to backup")
                    return
                }

                print("☁️ Backing up data to iCloud...")
                _ = await CloudKitManager.shared.backupData(memos: memos, categories: categories)
            } else if wasEnabled && !iCloudSyncEnabled {
                print("ℹ️ Pro expired - disabling iCloud sync")
            }
        }
    }

    // MARK: - Core Data Sync

    private func syncWithCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {
            // Load from Core Data
            let coreDataMemos = coreDataStack.fetchMemos()
            let coreDataCategories = coreDataStack.fetchCategories()

            // Merge with existing data (UserDefaults has priority for local changes)
            mergeMemos(from: coreDataMemos)
            mergeCategories(from: coreDataCategories)
        }
    }

    private func migrateUserDefaultsToCoreData() async {
        guard iCloudSyncEnabled else { return }

        await MainActor.run {

            // Migrate all memos to Core Data
            for memo in memos {
                coreDataStack.saveMemo(memo)
            }

            // Migrate all categories to Core Data
            for category in categories {
                coreDataStack.saveCategory(category)
            }

        }
    }

    private func mergeMemos(from coreDataMemos: [QuickMemo]) {
        // Simple merge strategy: combine unique memos
        var memoDict = Dictionary(uniqueKeysWithValues: memos.map { ($0.id, $0) })

        for cdMemo in coreDataMemos {
            if let existingMemo = memoDict[cdMemo.id] {
                // Use the newer version
                if cdMemo.updatedAt > existingMemo.updatedAt {
                    memoDict[cdMemo.id] = cdMemo
                }
            } else {
                memoDict[cdMemo.id] = cdMemo
            }
        }

        memos = Array(memoDict.values).sorted { $0.createdAt > $1.createdAt }
    }

    private func mergeCategories(from coreDataCategories: [Category]) {
        // Simple merge strategy: combine unique categories
        var categoryDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        for cdCategory in coreDataCategories {
            if categoryDict[cdCategory.id] == nil {
                categoryDict[cdCategory.id] = cdCategory
            }
        }

        categories = Array(categoryDict.values).sorted { $0.order < $1.order }
    }
    
    // MARK: - Memo Operations

    func addMemo(_ memo: QuickMemo) {
        var newMemo = memo

        // ハッシュタグを自動抽出（本文とタイトルから）
        let textToScan = "\(newMemo.title) \(newMemo.content)"
        let extractedHashtags = TagManager.shared.extractHashtagsFromText(textToScan)

        // 既存のタグに抽出したハッシュタグを追加（重複を避ける）
        let combinedTags = Array(Set(newMemo.tags + extractedHashtags))

        // 本文からハッシュタグを除去（オプション：必要に応じてコメントアウトを外す）
        // newMemo.content = TagManager.shared.removeHashtagsFromText(newMemo.content)

        newMemo.tags = combinedTags

        // Enforce tag limit for free users
        if !purchaseManager.isProVersion {
            let maxTags = purchaseManager.getMaxTagsPerMemo()
            if newMemo.tags.count > maxTags {
                newMemo.tags = Array(newMemo.tags.prefix(maxTags))
            }
        }

        // 抽出したハッシュタグをカテゴリーのタグコレクションに追加
        if !extractedHashtags.isEmpty {
            addTagsToCategory(tags: extractedHashtags, categoryName: newMemo.primaryCategory)
        }

        memos.append(newMemo)
        saveMemos()

        // Save to Core Data if Pro version
        if iCloudSyncEnabled {
            coreDataStack.saveMemo(newMemo)
        }
    }

    // 新しいメソッド: タグをカテゴリーに追加
    func addTagsToCategory(tags: [String], categoryName: String) {
        guard let categoryIndex = categories.firstIndex(where: { $0.name == categoryName }) else { return }

        // 既存のタグと新しいタグをマージ（重複を避ける）
        let existingTags = Set(categories[categoryIndex].defaultTags)
        let newTags = Set(tags)
        let mergedTags = Array(existingTags.union(newTags))

        // Pro版ユーザーまたはタグ数が制限内の場合のみ追加
        let maxTagsPerCategory = purchaseManager.isProVersion ? Int.max : 20
        categories[categoryIndex].defaultTags = Array(mergedTags.prefix(maxTagsPerCategory))

        saveCategories()
        print("📌 Added \(newTags.subtracting(existingTags).count) new tags to category '\(categoryName)'")
    }
    
    func deleteMemo(id: UUID) {
        // アーカイブに保存してから削除
        if let memoToDelete = memos.first(where: { $0.id == id }) {
            let archivedMemo = ArchivedMemo(memo: memoToDelete)
            archivedMemos.append(archivedMemo)
            saveArchivedMemos()
        }

        memos.removeAll { $0.id == id }
        saveMemos()

        // Delete from Core Data if Pro version
        if iCloudSyncEnabled {
            coreDataStack.deleteMemo(id: id)
        }
    }

    // 削除履歴から完全削除
    func deleteArchivedMemo(id: UUID) {
        archivedMemos.removeAll { $0.id == id }
        saveArchivedMemos()
    }

    // 削除履歴からメモを復元
    func restoreMemo(from archivedMemo: ArchivedMemo) {
        var restoredMemo = archivedMemo.originalMemo
        restoredMemo.updatedAt = Date()  // 復元時刻で更新
        addMemo(restoredMemo)

        // アーカイブから削除
        deleteArchivedMemo(id: archivedMemo.id)
    }

    // 削除履歴をクリア
    func clearArchivedMemos() {
        archivedMemos.removeAll()
        saveArchivedMemos()
    }
    
    func updateMemo(_ memo: QuickMemo) {
        var updatedMemo = memo

        // Enforce tag limit for free users
        if !purchaseManager.isProVersion {
            let maxTags = purchaseManager.getMaxTagsPerMemo()
            if updatedMemo.tags.count > maxTags {
                updatedMemo.tags = Array(updatedMemo.tags.prefix(maxTags))
            }
        }

        if let index = memos.firstIndex(where: { $0.id == updatedMemo.id }) {
            memos[index] = updatedMemo
            saveMemos()

            // Update in Core Data if Pro version
            if iCloudSyncEnabled {
                coreDataStack.saveMemo(updatedMemo)
            }
        }
    }
    
    // MARK: - Tag Visibility Management

    func toggleTagVisibility(tag: String, for categoryId: UUID) {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }

        if categories[index].hiddenTags.contains(tag) {
            categories[index].hiddenTags.remove(tag)
        } else {
            categories[index].hiddenTags.insert(tag)
        }
        saveCategories()
    }

    func getVisibleTags(for categoryId: UUID) -> [String] {
        guard let category = categories.first(where: { $0.id == categoryId }) else { return [] }

        // カテゴリーに属するすべてのメモのタグを取得
        let allTagsInCategory = memos
            .filter { $0.primaryCategory == category.name }
            .flatMap { $0.tags }

        // 重複を除去して、非表示タグを除外
        let uniqueTags = Set(allTagsInCategory)
        return uniqueTags.filter { !category.hiddenTags.contains($0) }.sorted()
    }

    func getAllTagsForCategory(categoryId: UUID) -> [(tag: String, isHidden: Bool)] {
        guard let category = categories.first(where: { $0.id == categoryId }) else { return [] }

        // カテゴリーに属するすべてのメモのタグを取得
        let allTagsInCategory = memos
            .filter { $0.primaryCategory == category.name }
            .flatMap { $0.tags }

        // 重複を除去
        let uniqueTags = Set(allTagsInCategory)

        // タグとその表示状態のタプル配列を返す
        return uniqueTags.map { tag in
            (tag: tag, isHidden: category.hiddenTags.contains(tag))
        }.sorted { $0.tag < $1.tag }
    }

    // MARK: - Category Operations
    
    func getCategory(named name: String) -> Category? {
        return categories.first { $0.name == name }
    }
    
    func updateCategory(_ category: Category) {
        // Remove Pro version check - allow category updates for all users
        // The Pro check should be at UI level, not data level

        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            let oldName = categories[index].name

            // Prevent renaming the "Other" default category
            let oldBaseKey = LocalizedCategories.baseKey(forLocalizedName: oldName)
            if oldBaseKey == "other" {
                var modifiedCategory = category
                modifiedCategory.name = oldName
                categories[index] = modifiedCategory
            } else {
                categories[index] = category
            }

            if oldName != category.name {
                updateMemosWithCategoryChange(oldName: oldName, newName: category.name)
            }

            saveCategories()
        }
    }

    func addCategory(_ category: Category) {
        // Remove Pro version check - allow adding categories
        // Pro limits should be enforced at UI level

        // Ensure unique name
        guard !categories.contains(where: { $0.name == category.name }) else {
            return
        }

        categories.append(category)
        saveCategories()
    }

    func deleteCategory(id: UUID) {
        // Remove Pro version check for deletion
        // Pro limits should be enforced at UI level

        guard let category = categories.first(where: { $0.id == id }) else { return }

        let destinationName = LocalizedCategories.localizedName(for: "other")

        // Move all memos from this category to the default "Other" bucket
        let memosToUpdate = memos.filter { $0.primaryCategory == category.name }
        for memo in memosToUpdate {
            var updatedMemo = memo
            updatedMemo.primaryCategory = destinationName
            updateMemo(updatedMemo)
        }

        categories.removeAll { $0.id == id }
        saveCategories()
    }

    func reorderCategories(_ categories: [Category]) {
        // Remove Pro version check - allow reordering
        // Pro limits should be enforced at UI level

        // Update order property based on new arrangement
        for (index, category) in categories.enumerated() {
            if let existingIndex = self.categories.firstIndex(where: { $0.id == category.id }) {
                self.categories[existingIndex].order = index
            }
        }

        // Sort by new order
        self.categories.sort { $0.order < $1.order }
        saveCategories()
    }

    private func updateMemosWithCategoryChange(oldName: String, newName: String) {
        for index in memos.indices {
            if memos[index].primaryCategory == oldName {
                memos[index].primaryCategory = newName
            }
        }
        saveMemos()
    }
    
    // MARK: - Tag Operations

    func addTag(to categoryName: String, tag: String) -> Bool {
        guard var category = getCategory(named: categoryName) else { return false }

        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return false }

        // Check tag limit for free users
        if !purchaseManager.isProVersion {
            let maxTags = purchaseManager.getMaxTagsPerMemo()
            if category.defaultTags.count >= maxTags {
                return false
            }
        }

        if !category.defaultTags.contains(trimmedTag) {
            category.defaultTags.append(trimmedTag)
            updateCategory(category)
            return true
        }
        return false
    }
    
    func removeTag(from categoryName: String, tag: String) {
        guard var category = getCategory(named: categoryName) else { return }
        
        category.defaultTags.removeAll { $0 == tag }
        updateCategory(category)
    }
    
    func updateTag(in categoryName: String, oldTag: String, newTag: String) {
        guard var category = getCategory(named: categoryName) else { return }
        
        let trimmedNewTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewTag.isEmpty else { return }
        
        if let index = category.defaultTags.firstIndex(of: oldTag) {
            category.defaultTags[index] = trimmedNewTag
            updateCategory(category)
        }
    }
    
    // MARK: - Search and Filter
    
    func filteredMemos(category: String, searchText: String = "") -> [QuickMemo] {
        var filtered = memos
        
        let localizationManager = LocalizationManager.shared
        let allCategoryNames: Set<String> = [
            localizationManager.localizedString(for: "category_all"),
            "すべて",
            "All",
            "全部"
        ]

        if !allCategoryNames.contains(category) {
            if let filterKey = LocalizedCategories.baseKey(forLocalizedName: category) {
                filtered = filtered.filter {
                    LocalizedCategories.baseKey(forLocalizedName: $0.primaryCategory) == filterKey
                }
            } else {
                filtered = filtered.filter { $0.primaryCategory == category }
            }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    func searchMemos(
        searchText: String,
        categories: Set<String>,
        tags: Set<String>,
        startDate: Date?,
        endDate: Date?
    ) -> [QuickMemo] {
        var filtered = memos
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !categories.isEmpty {
            filtered = filtered.filter { categories.contains($0.primaryCategory) }
        }
        
        if !tags.isEmpty {
            filtered = filtered.filter { memo in
                tags.allSatisfy { tag in
                    memo.tags.contains { $0.localizedCaseInsensitiveContains(tag) }
                }
            }
        }
        
        if let startDate = startDate {
            filtered = filtered.filter { $0.createdAt >= startDate }
        }
        
        if let endDate = endDate {
            filtered = filtered.filter { $0.createdAt <= endDate }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getAllTags() -> [String] {
        let allTags = memos.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    private func normalizeDefaultCategoryMetadata(for categories: inout [Category]) {
        for index in categories.indices {
            if let inferredKey = categories[index].baseKey ?? LocalizedCategories.baseKey(forLocalizedName: categories[index].name) {
                if LocalizedCategories.allLocalizedVariants(for: inferredKey).contains(categories[index].name) {
                    categories[index].baseKey = inferredKey
                    categories[index].isDefault = true
                }
            }
        }
    }

    @discardableResult
    private func migrateLegacyShoppingCategory() -> Bool {
        guard let index = categories.firstIndex(where: { category in
            let key = category.baseKey ?? LocalizedCategories.baseKey(forLocalizedName: category.name)
            return key == "shopping"
        }) else {
            return false
        }

        let oldName = categories[index].name

        categories[index].baseKey = "people"
        categories[index].isDefault = true
        categories[index].name = LocalizedCategories.localizedName(for: "people")
        categories[index].icon = LocalizedCategories.iconName(for: "people")
        categories[index].color = LocalizedCategories.colorHex(for: "people")
        categories[index].defaultTags = LocalizedCategories.defaultTagKeys(for: "people").map { $0.localized }

        if oldName != categories[index].name {
            updateMemosWithCategoryChange(oldName: oldName, newName: categories[index].name)
        }

        return true
    }

    // MARK: - Default Categories
    
    private func createDefaultCategories() {
        print("🎨 Creating default categories...")
        
        // Use LocalizedCategories to get localized category names
        let defaultCategories = LocalizedCategories.getDefaultCategories().enumerated().map { index, categoryInfo in
            Category(
                name: categoryInfo.name,
                icon: LocalizedCategories.iconName(for: categoryInfo.key),
                color: categoryInfo.color,
                order: index,
                defaultTags: LocalizedCategories.defaultTagKeys(for: categoryInfo.key).map { $0.localized },
                isDefault: true,
                baseKey: categoryInfo.key
            )
        }

        // Add "Other" category
        let otherCategory = Category(
            name: LocalizedCategories.localizedName(for: "other"),
            icon: LocalizedCategories.iconName(for: "other"),
            color: LocalizedCategories.colorHex(for: "other"),
            order: defaultCategories.count,
            defaultTags: LocalizedCategories.defaultTagKeys(for: "other").map { $0.localized },
            isDefault: true,
            baseKey: "other"
        )

        categories = defaultCategories + [otherCategory]
        saveCategories()
        
        print("✅ Created \(categories.count) default categories")
    }

    private func ensureDefaultCategoriesExist() {
        // デフォルトカテゴリーのキーリスト
        let requiredDefaultKeys = ["work", "personal", "idea", "people", "other"]
        let existingBaseKeys = categories.compactMap { $0.baseKey }

        // 不足しているデフォルトカテゴリーを検出
        let missingKeys = requiredDefaultKeys.filter { !existingBaseKeys.contains($0) }

        if !missingKeys.isEmpty {
            print("📝 Restoring missing default categories: \(missingKeys)")

            for key in missingKeys {
                let order = categories.count

                let category = Category(
                    name: LocalizedCategories.localizedName(for: key),
                    icon: LocalizedCategories.iconName(for: key),
                    color: LocalizedCategories.colorHex(for: key),
                    order: order,
                    defaultTags: LocalizedCategories.defaultTagKeys(for: key).map { $0.localized },
                    isDefault: true,
                    baseKey: key
                )

                categories.append(category)
            }

            // 順序を再調整
            reorderCategories()
            saveCategories()
        } else {
            print("✅ All default categories are present")
        }
    }

    private func reorderCategories() {
        // デフォルトカテゴリーを先頭に、カスタムカテゴリーを後ろに配置
        let defaultCats = categories.filter { $0.isDefault }.sorted {
            let order1 = ["work", "personal", "idea", "people", "other"].firstIndex(of: $0.baseKey ?? "") ?? 999
            let order2 = ["work", "personal", "idea", "people", "other"].firstIndex(of: $1.baseKey ?? "") ?? 999
            return order1 < order2
        }
        let customCats = categories.filter { !$0.isDefault }.sorted { $0.order < $1.order }

        categories = defaultCats + customCats

        // 順序番号を更新
        for (index, _) in categories.enumerated() {
            categories[index].order = index
        }
    }

    private func getIconForCategory(_ name: String) -> String {
        let key = LocalizedCategories.baseKey(forLocalizedName: name) ?? name
        return LocalizedCategories.iconName(for: key)
    }

    private func getDefaultTagsForCategory(_ name: String) -> [String] {
        let key = LocalizedCategories.baseKey(forLocalizedName: name) ?? name
        return LocalizedCategories.defaultTagKeys(for: key).map { $0.localized }
    }

    private func getBaseKeyForCategory(_ name: String) -> String {
        LocalizedCategories.baseKey(forLocalizedName: name) ?? "other"
    }

    // カテゴリー名が変更された場合の検証
    func canRenameCategory(from oldName: String, to newName: String) -> Bool {
        // Remove Pro check - allow renaming for all users
        // Pro limits should be enforced at UI level

        // その他カテゴリーは名前変更不可
        if LocalizedCategories.baseKey(forLocalizedName: oldName) == "other" {
            return false
        }

        // 既存のカテゴリー名との重複チェック
        return !categories.contains { $0.name == newName && $0.name != oldName }
    }

    // カテゴリーが削除可能かチェック
    func canDeleteCategory(_ category: Category) -> Bool {
        // Allow deletion check for all users
        // Pro limits should be enforced at UI level

        // その他カテゴリーは削除不可
        return LocalizedCategories.baseKey(forLocalizedName: category.name) != "other"
    }
    
    // MARK: - Purchase Validation

    @MainActor
    func canAddMemo() -> Bool {
        // Pro版は無制限
        if purchaseManager.isProVersion {
            return true
        }

        // 無料版の通常枠（100個まで）
        if memos.count < 100 {
            return true
        }

        // 報酬メモがあれば作成可能
        return RewardManager.shared.hasRewardMemos
    }

    /// メモ作成時にどの枠を使用するか決定し、必要に応じて報酬メモを消費
    /// - Returns: メモを作成できる場合はtrue
    @MainActor
    func consumeMemoSlotIfNeeded() -> Bool {
        // Pro版は消費不要
        if purchaseManager.isProVersion {
            return true
        }

        // 無料版の通常枠内
        if memos.count < 100 {
            return true
        }

        // 報酬メモを消費
        return RewardManager.shared.consumeRewardMemo()
    }

    /// メモ作成時の枠タイプを取得
    @MainActor
    func getMemoSlotType() -> MemoSlotType {
        return RewardManager.shared.determineMemoSlotType(
            currentMemoCount: memos.count,
            isProVersion: purchaseManager.isProVersion
        )
    }
    
    @MainActor
    func canAddCategory() -> Bool {
        // Pro版は無制限
        if purchaseManager.isProVersion {
            return true
        }

        // 無料版の通常枠（5個まで）
        if categories.count < 5 {
            return true
        }

        // 報酬カテゴリーがあれば作成可能
        return RewardManager.shared.hasRewardCategories
    }

    /// カテゴリー作成時にどの枠を使用するか決定し、必要に応じて報酬カテゴリーを消費
    /// - Returns: カテゴリーを作成できる場合はtrue
    @MainActor
    func consumeCategorySlotIfNeeded() -> Bool {
        // Pro版は消費不要
        if purchaseManager.isProVersion {
            return true
        }

        // 無料版の通常枠内
        if categories.count < 5 {
            return true
        }

        // 報酬カテゴリーを消費
        return RewardManager.shared.consumeRewardCategory()
    }

    /// カテゴリー作成時の枠タイプを取得
    @MainActor
    func getCategorySlotType() -> CategorySlotType {
        return RewardManager.shared.determineCategorySlotType(
            currentCategoryCount: categories.count,
            isProVersion: purchaseManager.isProVersion
        )
    }

    @MainActor
    func canUseAdvancedTags() -> Bool {
        return purchaseManager.canUseAdvancedFeatures()
    }

    @MainActor
    func canUseCalendarIntegration() -> Bool {
        return purchaseManager.canUseAdvancedFeatures()
    }

    @MainActor
    func canUseDeepLinks() -> Bool {
        return purchaseManager.canUseAdvancedFeatures()
    }

    @MainActor
    func getRemainingMemoCount() -> Int? {
        if purchaseManager.isProVersion {
            return nil // Unlimited
        }
        return max(0, 100 - memos.count)
    }

    @MainActor
    func getRemainingCategoryCount() -> Int? {
        if purchaseManager.isProVersion {
            return nil // Unlimited
        }
        // 基本枠5 + リワード枠
        let baseLimit = 5
        let rewardSlots = RewardManager.shared.rewardCategoryCount
        let totalLimit = baseLimit + rewardSlots
        return max(0, totalLimit - categories.count)
    }

    // MARK: - Widget Management

    func getWidgetCategories() -> [String] {
        print("🔍 DataManager.getWidgetCategories called")

        // Get selected widget categories from UserDefaults
        if let data = userDefaults.data(forKey: widgetCategoriesKey),
           let categories = try? JSONDecoder().decode([String].self, from: data) {
            print("✅ DataManager: Found \(categories.count) widget categories")
            print("✅ Categories: \(categories)")
            return categories
        }

        // Default to first 4 categories
        let defaultCategories = Array(categories.prefix(4).map { $0.name })
        print("⚠️ DataManager: No widget categories found, returning default: \(defaultCategories)")
        return defaultCategories
    }

    func saveWidgetCategories(_ categoryNames: [String]) {
        print("🔧 DataManager.saveWidgetCategories called with \(categoryNames.count) categories")
        print("🔧 Categories: \(categoryNames)")
        print("🔧 Pro version: \(purchaseManager.isProVersion)")

        // Free users cannot customize widget categories
        guard purchaseManager.isProVersion else {
            print("❌ DataManager: Not Pro version, cannot save widget categories")
            return
        }

        if let data = try? JSONEncoder().encode(categoryNames) {
            userDefaults.set(data, forKey: widgetCategoriesKey)
            userDefaults.synchronize()
            print("✅ DataManager: Saved \(categoryNames.count) categories to widget_categories")
            notifyWidgetUpdate()
            print("✅ DataManager: Widget update notification sent")
        } else {
            print("❌ DataManager: Failed to encode widget categories")
        }
    }

    @MainActor
    func canCustomizeWidgetCategories() -> Bool {
        return purchaseManager.canCustomizeWidget()
    }

    // MARK: - Debug Methods

    /// ウィジェット設定の診断情報を出力
    func diagnoseWidgetSettings() {
        print("🔍 ===== Widget Settings Diagnosis =====")
        print("📊 Pro Version: \(purchaseManager.isProVersion)")
        print("📊 App Group ID: \(appGroupIdentifier)")

        // App Group UserDefaults の確認
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("✅ App Group UserDefaults accessible")

            // Pro版状態の確認
            let isPro1 = sharedDefaults.bool(forKey: "is_pro_version")
            let isPro2 = sharedDefaults.bool(forKey: "isPurchased")
            print("📊 is_pro_version: \(isPro1)")
            print("📊 isPurchased: \(isPro2)")

            // widget_categories の確認
            if let data = sharedDefaults.data(forKey: "widget_categories"),
               let categories = try? JSONDecoder().decode([String].self, from: data) {
                print("✅ widget_categories found: \(categories)")
            } else {
                print("⚠️ widget_categories not found or decode failed")
            }

            // categories の確認
            if let data = sharedDefaults.data(forKey: "categories") {
                print("✅ categories data exists (\(data.count) bytes)")
                if let categories = try? JSONDecoder().decode([Category].self, from: data) {
                    print("✅ Decoded \(categories.count) categories")
                } else {
                    print("❌ Failed to decode categories")
                }
            } else {
                print("⚠️ categories data not found")
            }
        } else {
            print("❌ Failed to access App Group UserDefaults")
        }

        print("🔍 ===== End Diagnosis =====")
    }
    
    // MARK: - Diagnostic Methods
    
    /// カテゴリーの状態を診断して修復を試みる
    func diagnoseAndRepairCategories() {
        print("🔧 Starting category diagnosis and repair...")
        print("📊 Current state: \(categories.count) categories in memory")
        
        // UserDefaultsから直接読み込みを試みる
        userDefaults.synchronize()
        
        if let data = userDefaults.data(forKey: categoriesKey) {
            print("✅ Found category data in UserDefaults")
            
            do {
                let decodedCategories = try JSONDecoder().decode([Category].self, from: data)
                print("📦 UserDefaults contains \(decodedCategories.count) categories")
                
                if categories.isEmpty && !decodedCategories.isEmpty {
                    print("🔄 Memory categories empty but UserDefaults has data. Restoring...")
                    categories = decodedCategories
                    objectWillChange.send()
                    print("✅ Restored \(categories.count) categories to memory")
                } else if categories.count != decodedCategories.count {
                    print("⚠️ Category count mismatch - Memory: \(categories.count), UserDefaults: \(decodedCategories.count)")
                }
                
                // カテゴリーの詳細を出力
                for (index, cat) in decodedCategories.enumerated() {
                    print("  [\(index)] \(cat.name) - baseKey: \(cat.baseKey ?? "nil"), isDefault: \(cat.isDefault)")
                }
            } catch {
                print("❌ Failed to decode categories from UserDefaults: \(error)")
            }
        } else {
            print("❌ No category data found in UserDefaults")

            if categories.isEmpty {
                // 🚨 重要: iCloud復元処理が完了するまではデフォルトカテゴリーを作成しない
                // これにより、iCloudからのデータ復元を妨げない
                if isCloudRestoreComplete {
                    print("🆘 Both memory and UserDefaults are empty. Creating defaults...")
                    createDefaultCategories()
                    objectWillChange.send()
                } else {
                    print("⏳ iCloud restore not complete yet, skipping default category creation")
                }
            }
        }

        print("📋 Diagnosis complete. Final category count: \(categories.count)")
    }
    
    /// カテゴリーを強制的に再読み込みする
    func forceReloadCategories() {
        print("🔄 Force reloading categories...")
        
        // UserDefaultsを同期
        userDefaults.synchronize()
        
        // カテゴリーを再読み込み
        loadCategories()
        
        // カテゴリーが空の場合はデフォルトを作成
        if categories.isEmpty {
            print("⚠️ Categories still empty after reload. Creating defaults...")
            createDefaultCategories()
        }
        
        // UIを更新
        objectWillChange.send()
        
        print("✅ Force reload complete. Category count: \(categories.count)")
    }
}
