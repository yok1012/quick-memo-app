import Foundation
import CloudKit
import StoreKit
import os.log

// CloudKit専用のログカテゴリ
private let cloudKitLog = OSLog(subsystem: "yokAppDev.quickMemoApp", category: "CloudKit")

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    // Record Types
    private let subscriptionRecordType = "SubscriptionStatus"
    private let memoRecordType = "QuickMemo"
    private let categoryRecordType = "Category"
    private let backupRecordType = "DataBackup"

    @Published var isSyncing: Bool = false
    @Published var syncError: String?
    @Published var lastSyncDate: Date?
    @Published var lastBackupDate: Date?
    @Published var backupStatus: BackupStatus = .unknown

    enum BackupStatus {
        case unknown
        case syncing
        case success
        case failed(String)
        case noAccount
    }

    private init() {
        // CloudKitコンテナを初期化
        // デフォルトコンテナ（Bundle IDベース: iCloud.yokAppDev.quickMemoApp）を使用
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase

        #if DEBUG
        // デバッグ時にコンテナIDを出力
        print("CloudKit Container ID: \(container.containerIdentifier ?? "unknown")")
        #endif
    }

    // MARK: - Subscription Status Management

    /// 購入状態をCloudKitに保存（iCloudアカウントのみ必要、Sign in with Appleは不要）
    func saveSubscriptionStatus(transactionID: String, productID: String) async {
        print("🔄 CloudKit: saveSubscriptionStatus started")
        print("  - TransactionID: \(transactionID)")
        print("  - ProductID: \(productID)")

        // iCloudアカウントの状態を確認
        let accountStatus = await checkiCloudAccountStatus()
        print("  - iCloud Account Status: \(accountStatusDescription(accountStatus))")

        if accountStatus != .available {
            let errorMsg = accountStatusErrorMessage(accountStatus)
            print("❌ CloudKit Error: \(errorMsg)")
            syncError = errorMsg
            return
        }

        isSyncing = true
        syncError = nil

        do {
            // レコードIDを作成（固定キー - プライベートDBはユーザー毎に分離されている）
            let recordID = CKRecord.ID(recordName: "subscription_status")
            print("  - RecordID: \(recordID.recordName)")

            // 既存のレコードを取得または新規作成
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
                print("  ✅ Existing record found")
            } catch {
                // レコードが存在しない場合は新規作成
                record = CKRecord(recordType: subscriptionRecordType, recordID: recordID)
                print("  ✅ Creating new record")
            }

            // フィールドを更新
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            record["transactionID"] = transactionID as CKRecordValue
            record["productID"] = productID as CKRecordValue
            record["isPro"] = Int64(1) as CKRecordValue
            record["lastUpdated"] = Date() as CKRecordValue
            record["deviceID"] = deviceID as CKRecordValue

            print("  📝 Record fields set:")
            print("    - transactionID: \(transactionID)")
            print("    - productID: \(productID)")
            print("    - isPro: 1")
            print("    - deviceID: \(deviceID)")

            // レコードを保存
            let savedRecord = try await privateDatabase.save(record)
            print("  ✅ Record saved successfully: \(savedRecord.recordID.recordName)")

            lastSyncDate = Date()
            isSyncing = false

            print("✅ CloudKit: saveSubscriptionStatus completed successfully")
        } catch let ckError as CKError {
            let errorMessage = cloudKitErrorMessage(ckError)
            print("❌ \(errorMessage)")
            syncError = errorMessage
            isSyncing = false
        } catch {
            let errorMessage = "Failed to save subscription status: \(error.localizedDescription)"
            print("❌ \(errorMessage)")
            syncError = errorMessage
            isSyncing = false
        }
    }

    /// 購入状態をCloudKitから取得して復元
    func fetchSubscriptionStatus() async -> (isPro: Bool, transactionID: String?) {
        // iCloudアカウントの確認
        let accountStatus = await checkiCloudAccountStatus()
        if accountStatus != .available {
            return (false, nil)
        }

        isSyncing = true
        syncError = nil

        do {
            let recordID = CKRecord.ID(recordName: "subscription_status")
            let record = try await privateDatabase.record(for: recordID)

            // isPro は Int64 として保存されているので、適切に変換
            let isProValue = record["isPro"] as? Int64 ?? 0
            let isPro = isProValue > 0
            let transactionID = record["transactionID"] as? String

            lastSyncDate = Date()
            isSyncing = false

            return (isPro, transactionID)
        } catch {
            // レコードが見つからない場合はProではない
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                isSyncing = false
                return (false, nil)
            }

            syncError = "Failed to fetch subscription status: \(error.localizedDescription)"
            isSyncing = false
            return (false, nil)
        }
    }

    /// 購入状態を同期（iCloudアカウントのみ必要）
    func syncSubscriptionStatus() async {
        print("🔄 CloudKit: syncSubscriptionStatus started")

        // iCloudアカウントの確認
        let accountStatus = await checkiCloudAccountStatus()
        if accountStatus != .available {
            print("  ⚠️ iCloud not available, skipping sync")
            return
        }

        // CloudKitから権利情報を取得
        let (isPro, transactionID) = await fetchSubscriptionStatus()
        print("  - CloudKit status: isPro=\(isPro), transactionID=\(transactionID ?? "nil")")

        if isPro {
            // CloudKitにPro版の記録がある場合、ローカルでもPro版として扱う
            print("  ✅ Pro status found in CloudKit, updating local")
            await MainActor.run {
                PurchaseManager.shared.isProVersion = true
            }
        } else {
            // ローカルの購入状態を確認
            if PurchaseManager.shared.isProVersion {
                print("  📝 Local is Pro but CloudKit isn't, syncing to CloudKit")
                // ローカルでPro版の場合、CloudKitに保存
                if let transaction = await getLatestTransaction() {
                    print("  - Found transaction: \(transaction.id)")
                    await saveSubscriptionStatus(
                        transactionID: String(transaction.id),
                        productID: transaction.productID
                    )
                } else {
                    print("  ⚠️ No transaction found to sync")
                }
            } else {
                print("  ℹ️ Not Pro on either local or CloudKit")
            }
        }

        print("✅ CloudKit: syncSubscriptionStatus completed")
    }

    /// 購入状態をクリア
    func clearSubscriptionStatus() async {
        do {
            let recordID = CKRecord.ID(recordName: "subscription_status")
            _ = try await privateDatabase.deleteRecord(withID: recordID)
        } catch {
            // エラーは無視（既に削除されている可能性もある）
        }
    }

    /// CloudKitエラーメッセージ
    private func cloudKitErrorMessage(_ error: CKError) -> String {
        switch error.code {
        case .networkFailure, .networkUnavailable:
            return "ネットワークに接続できません。インターネット接続を確認してください。"
        case .notAuthenticated:
            return "iCloudにサインインしていません。設定アプリでサインインしてください。"
        case .quotaExceeded:
            return "iCloudの容量が不足しています。"
        case .permissionFailure:
            return "iCloudへのアクセス権限がありません。"
        default:
            return "CloudKitエラー: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    /// 最新のトランザクションを取得
    private func getLatestTransaction() async -> StoreKit.Transaction? {
        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            switch verificationResult {
            case let .verified(transaction):
                if transaction.revocationDate == nil {
                    return transaction
                }
            case .unverified:
                continue
            }
        }
        return nil
    }

    // MARK: - iCloud Account Status

    /// iCloudアカウントの状態を確認
    func checkiCloudAccountStatus() async -> CKAccountStatus {
        do {
            let status = try await container.accountStatus()
            return status
        } catch {
            syncError = "Failed to check iCloud account status: \(error.localizedDescription)"
            return .couldNotDetermine
        }
    }

    /// iCloudが利用可能かチェック
    func isiCloudAvailable() async -> Bool {
        let status = await checkiCloudAccountStatus()
        let isAvailable = status == .available
        print("🔍 CloudKit: iCloud Available = \(isAvailable) (status: \(status.rawValue))")
        return isAvailable
    }

    /// アカウントステータスの説明文
    private func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "利用可能"
        case .noAccount:
            return "iCloudアカウントなし"
        case .restricted:
            return "制限あり"
        case .couldNotDetermine:
            return "確認できず"
        case .temporarilyUnavailable:
            return "一時的に利用不可"
        @unknown default:
            return "不明 (\(status.rawValue))"
        }
    }

    /// アカウントステータスに基づくエラーメッセージ
    private func accountStatusErrorMessage(_ status: CKAccountStatus) -> String {
        switch status {
        case .noAccount:
            return "iCloudにサインインしていません。\n\n設定アプリ → Apple ID → iCloud でサインインしてください。"
        case .restricted:
            return "iCloudの使用が制限されています。\n\nペアレンタルコントロールや企業の管理設定を確認してください。"
        case .couldNotDetermine:
            return "iCloudの状態を確認できませんでした。\n\nネットワーク接続を確認してください。"
        case .temporarilyUnavailable:
            return "iCloudが一時的に利用できません。\n\nしばらく待ってから再試行してください。"
        default:
            return "iCloudに接続できません。"
        }
    }

    /// デバッグ用：CloudKit設定を出力
    func printDebugInfo() {
        print("=== CloudKit Debug Info ===")
        print("Container ID: \(container.containerIdentifier ?? "unknown")")
        print("Is Syncing: \(isSyncing)")
        print("Last Sync Date: \(lastSyncDate?.description ?? "never")")
        print("Last Backup Date: \(lastBackupDate?.description ?? "never")")
        print("Sync Error: \(syncError ?? "none")")
        print("=========================")
    }

    // MARK: - Data Backup (Memos & Categories)

    /// 固定のレコードID - Private Databaseはユーザーごとに分離されているため、
    /// デバイスIDに依存せず固定IDで良い
    private let primaryBackupRecordName = "primary_backup"

    /// メモとカテゴリーをiCloudにバックアップ
    /// 🚨 重要: 固定のレコードID（primary_backup）を使用
    /// これによりアプリ再インストール後も同じ場所からデータを取得可能
    func backupData(memos: [QuickMemo], categories: [Category]) async -> Bool {
        os_log("☁️ backupData: Starting with %d memos, %d categories", log: cloudKitLog, type: .info, memos.count, categories.count)
        print("☁️ ==========================================")
        print("☁️ CloudKit: Starting data backup...")
        print("☁️ ==========================================")

        // iCloudアカウントの確認
        let accountStatus = await checkiCloudAccountStatus()
        print("  📱 iCloud Account Status: \(accountStatusDescription(accountStatus))")

        if accountStatus != .available {
            let errorMsg = accountStatusErrorMessage(accountStatus)
            print("❌ iCloud account not available: \(errorMsg)")
            backupStatus = .failed(errorMsg)
            syncError = errorMsg
            return false
        }

        backupStatus = .syncing
        isSyncing = true
        syncError = nil

        do {
            // データをJSONにエンコード
            // 🚨 重要: UserDefaultsと同じデフォルトの日付戦略を使用（互換性のため）
            let encoder = JSONEncoder()
            // encoder.dateEncodingStrategy = .iso8601  // UserDefaultsと互換性のためコメントアウト

            let memosData = try encoder.encode(memos)
            let categoriesData = try encoder.encode(categories)

            print("  📦 Data to backup:")
            print("     - Memos: \(memos.count) (\(memosData.count) bytes)")
            print("     - Categories: \(categories.count) (\(categoriesData.count) bytes)")

            // 🚨 重要: 固定のレコードIDを使用（デバイスIDに依存しない）
            let recordID = CKRecord.ID(recordName: primaryBackupRecordName)
            print("  🔑 Record ID: \(recordID.recordName)")

            let record: CKRecord

            // 既存のレコードを取得または新規作成
            do {
                record = try await privateDatabase.record(for: recordID)
                print("  ✅ Found existing backup record, updating...")
            } catch {
                record = CKRecord(recordType: backupRecordType, recordID: recordID)
                print("  ✅ Creating new backup record...")
            }

            // フィールドを設定
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            record["deviceID"] = deviceID as CKRecordValue
            record["memosData"] = memosData as CKRecordValue
            record["categoriesData"] = categoriesData as CKRecordValue
            record["memosCount"] = Int64(memos.count) as CKRecordValue
            record["categoriesCount"] = Int64(categories.count) as CKRecordValue
            record["lastBackupDate"] = Date() as CKRecordValue
            record["appVersion"] = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") as CKRecordValue

            // レコードを保存
            os_log("💾 Saving record to CloudKit...", log: cloudKitLog, type: .info)
            let savedRecord = try await privateDatabase.save(record)

            lastBackupDate = Date()
            backupStatus = .success
            isSyncing = false

            // バックアップ日時をUserDefaultsにも保存
            UserDefaults.standard.set(Date(), forKey: "lastCloudBackupDate")

            os_log("✅ Backup SUCCESS! Record: %{public}@, memos: %d, categories: %d", log: cloudKitLog, type: .info, savedRecord.recordID.recordName, memos.count, categories.count)
            print("  ✅ Backup saved successfully!")
            print("     - Record: \(savedRecord.recordID.recordName)")
            print("     - Memos: \(memos.count)")
            print("     - Categories: \(categories.count)")
            print("☁️ ==========================================")

            return true

        } catch let ckError as CKError {
            let errorMessage = "CloudKit Error: \(ckError.code.rawValue) - \(ckError.localizedDescription)"
            print("❌ \(errorMessage)")
            backupStatus = .failed(errorMessage)
            syncError = errorMessage
            isSyncing = false
            return false
        } catch {
            let errorMessage = "Backup failed: \(error.localizedDescription)"
            print("❌ \(errorMessage)")
            backupStatus = .failed(errorMessage)
            syncError = errorMessage
            isSyncing = false
            return false
        }
    }

    /// iCloudからデータを復元
    /// 🚨 シンプルな実装: 固定のレコードID（primary_backup）から直接フェッチ
    func restoreData() async -> (memos: [QuickMemo], categories: [Category])? {
        os_log("☁️ CloudKit: Starting data restore...", log: cloudKitLog, type: .info)
        print("☁️ ==========================================")
        print("☁️ CloudKit: Starting data restore...")
        print("☁️ ==========================================")

        // iCloudアカウントの確認
        let accountStatus = await checkiCloudAccountStatus()
        os_log("📱 iCloud Account Status: %{public}@", log: cloudKitLog, type: .info, accountStatusDescription(accountStatus))
        print("  📱 iCloud Account Status: \(accountStatusDescription(accountStatus))")

        if accountStatus != .available {
            let errorMsg = accountStatusErrorMessage(accountStatus)
            os_log("❌ iCloud not available: %{public}@", log: cloudKitLog, type: .error, errorMsg)
            print("❌ iCloud account not available: \(errorMsg)")
            backupStatus = .failed(errorMsg)
            syncError = errorMsg
            return nil
        }

        backupStatus = .syncing
        isSyncing = true
        syncError = nil

        // 🚨 シンプルに固定のレコードIDでフェッチ
        let recordID = CKRecord.ID(recordName: primaryBackupRecordName)
        os_log("🔑 Looking for record: %{public}@", log: cloudKitLog, type: .info, recordID.recordName)
        print("  🔑 Looking for record: \(recordID.recordName)")

        do {
            let record = try await privateDatabase.record(for: recordID)

            let memosCount = record["memosCount"] as? Int64 ?? 0
            let categoriesCount = record["categoriesCount"] as? Int64 ?? 0
            let backupDate = record["lastBackupDate"] as? Date
            let deviceID = record["deviceID"] as? String ?? "unknown"

            os_log("✅ Found backup! DeviceID=%{public}@, Memos=%lld, Categories=%lld", log: cloudKitLog, type: .info, deviceID, memosCount, categoriesCount)
            print("  ✅ Found backup!")
            print("     - DeviceID: \(deviceID)")
            print("     - Date: \(backupDate?.description ?? "unknown")")
            print("     - Memos: \(memosCount)")
            print("     - Categories: \(categoriesCount)")

            // データをデコード
            // 🚨 重要: UserDefaultsと同じデフォルトの日付戦略を使用（互換性のため）
            let decoder = JSONDecoder()
            // decoder.dateDecodingStrategy = .iso8601  // UserDefaultsと互換性のためコメントアウト

            var restoredMemos: [QuickMemo] = []
            var restoredCategories: [Category] = []

            if let memosData = record["memosData"] as? Data {
                // デフォルトフォーマットでデコードを試み、失敗したらiso8601を試す
                do {
                    restoredMemos = try decoder.decode([QuickMemo].self, from: memosData)
                } catch {
                    os_log("⚠️ Default decode failed, trying iso8601: %{public}@", log: cloudKitLog, type: .info, error.localizedDescription)
                    let iso8601Decoder = JSONDecoder()
                    iso8601Decoder.dateDecodingStrategy = .iso8601
                    restoredMemos = try iso8601Decoder.decode([QuickMemo].self, from: memosData)
                }
                os_log("✅ Decoded %d memos", log: cloudKitLog, type: .info, restoredMemos.count)
                print("  ✅ Decoded \(restoredMemos.count) memos")
            } else {
                os_log("⚠️ memosData is nil in record", log: cloudKitLog, type: .error)
            }

            if let categoriesData = record["categoriesData"] as? Data {
                // デフォルトフォーマットでデコードを試み、失敗したらiso8601を試す
                do {
                    restoredCategories = try decoder.decode([Category].self, from: categoriesData)
                } catch {
                    os_log("⚠️ Default decode failed, trying iso8601: %{public}@", log: cloudKitLog, type: .info, error.localizedDescription)
                    let iso8601Decoder = JSONDecoder()
                    iso8601Decoder.dateDecodingStrategy = .iso8601
                    restoredCategories = try iso8601Decoder.decode([Category].self, from: categoriesData)
                }
                os_log("✅ Decoded %d categories", log: cloudKitLog, type: .info, restoredCategories.count)
                print("  ✅ Decoded \(restoredCategories.count) categories")
            } else {
                os_log("⚠️ categoriesData is nil in record", log: cloudKitLog, type: .error)
            }

            if let lastBackup = backupDate {
                lastBackupDate = lastBackup
            }

            backupStatus = .success
            isSyncing = false

            os_log("🎉 Restore SUCCESS: memos=%d, categories=%d", log: cloudKitLog, type: .info, restoredMemos.count, restoredCategories.count)
            print("🎉 ==========================================")
            print("🎉 CloudKit: Restore completed successfully!")
            print("🎉 Memos: \(restoredMemos.count), Categories: \(restoredCategories.count)")
            print("🎉 ==========================================")

            return (restoredMemos, restoredCategories)

        } catch let ckError as CKError {
            if ckError.code == .unknownItem {
                os_log("ℹ️ No backup found (record doesn't exist)", log: cloudKitLog, type: .info)
                print("  ℹ️ No backup found (record doesn't exist)")
                backupStatus = .failed("No backup found")
            } else {
                let errorMessage = "CloudKit Error: \(ckError.code.rawValue) - \(ckError.localizedDescription)"
                os_log("❌ %{public}@", log: cloudKitLog, type: .error, errorMessage)
                print("❌ \(errorMessage)")
                backupStatus = .failed(errorMessage)
                syncError = errorMessage
            }
            isSyncing = false
            return nil
        } catch {
            let errorMessage = "Restore failed: \(error.localizedDescription)"
            os_log("❌ %{public}@", log: cloudKitLog, type: .error, errorMessage)
            print("❌ \(errorMessage)")
            backupStatus = .failed(errorMessage)
            syncError = errorMessage
            isSyncing = false
            return nil
        }
    }

    /// 利用可能なバックアップ情報を取得
    /// 固定のレコードIDで直接フェッチ
    func getBackupInfo() async -> (date: Date?, memosCount: Int, categoriesCount: Int, deviceID: String?)? {
        os_log("🔍 getBackupInfo: Checking for backup...", log: cloudKitLog, type: .info)
        print("🔍 getBackupInfo: Checking for backup...")

        let accountStatus = await checkiCloudAccountStatus()
        if accountStatus != .available {
            os_log("❌ getBackupInfo: iCloud not available", log: cloudKitLog, type: .error)
            print("❌ getBackupInfo: iCloud not available")
            return nil
        }

        let recordID = CKRecord.ID(recordName: primaryBackupRecordName)
        os_log("🔍 getBackupInfo: Looking for record '%{public}@'", log: cloudKitLog, type: .info, recordID.recordName)
        print("🔍 getBackupInfo: Looking for record '\(recordID.recordName)'")

        do {
            let record = try await privateDatabase.record(for: recordID)

            // 🔍 デバッグ: レコードの全キーを出力
            print("📦 Record keys: \(record.allKeys())")
            for key in record.allKeys() {
                let value = record[key]
                print("   - \(key): \(String(describing: value)) (type: \(type(of: value)))")
            }

            let date = record["lastBackupDate"] as? Date
            let memosCount = record["memosCount"] as? Int64 ?? 0
            let categoriesCount = record["categoriesCount"] as? Int64 ?? 0
            let deviceID = record["deviceID"] as? String

            // 🔍 memosDataとcategoriesDataの存在確認
            let hasMemosData = record["memosData"] != nil
            let hasCategoriesData = record["categoriesData"] != nil
            print("📦 Data fields: memosData=\(hasMemosData), categoriesData=\(hasCategoriesData)")

            if let memosData = record["memosData"] as? Data {
                print("📦 memosData size: \(memosData.count) bytes")
                // デコードを試みてエラーを確認
                do {
                    let decoder = JSONDecoder()
                    let testMemos = try decoder.decode([QuickMemo].self, from: memosData)
                    print("✅ memosData can be decoded: \(testMemos.count) memos")
                } catch {
                    print("❌ memosData decode error: \(error)")
                }
            }

            if let categoriesData = record["categoriesData"] as? Data {
                print("📦 categoriesData size: \(categoriesData.count) bytes")
                // デコードを試みてエラーを確認
                do {
                    let decoder = JSONDecoder()
                    let testCategories = try decoder.decode([Category].self, from: categoriesData)
                    print("✅ categoriesData can be decoded: \(testCategories.count) categories")
                } catch {
                    print("❌ categoriesData decode error: \(error)")
                }
            }

            // 🔧 memosCount/categoriesCountが0の場合、実際のデータからカウントを取得
            var actualMemosCount = Int(memosCount)
            var actualCategoriesCount = Int(categoriesCount)

            if actualMemosCount == 0, let memosData = record["memosData"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let testMemos = try decoder.decode([QuickMemo].self, from: memosData)
                    actualMemosCount = testMemos.count
                    print("🔧 Fixed memosCount from data: \(actualMemosCount)")
                } catch {
                    // iso8601も試す
                    let iso8601Decoder = JSONDecoder()
                    iso8601Decoder.dateDecodingStrategy = .iso8601
                    if let testMemos = try? iso8601Decoder.decode([QuickMemo].self, from: memosData) {
                        actualMemosCount = testMemos.count
                        print("🔧 Fixed memosCount from data (iso8601): \(actualMemosCount)")
                    }
                }
            }

            if actualCategoriesCount == 0, let categoriesData = record["categoriesData"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let testCategories = try decoder.decode([Category].self, from: categoriesData)
                    actualCategoriesCount = testCategories.count
                    print("🔧 Fixed categoriesCount from data: \(actualCategoriesCount)")
                } catch {
                    // iso8601も試す
                    let iso8601Decoder = JSONDecoder()
                    iso8601Decoder.dateDecodingStrategy = .iso8601
                    if let testCategories = try? iso8601Decoder.decode([Category].self, from: categoriesData) {
                        actualCategoriesCount = testCategories.count
                        print("🔧 Fixed categoriesCount from data (iso8601): \(actualCategoriesCount)")
                    }
                }
            }

            os_log("✅ getBackupInfo: Found backup! memos=%d, categories=%d, deviceID=%{public}@", log: cloudKitLog, type: .info, actualMemosCount, actualCategoriesCount, deviceID ?? "nil")
            print("✅ getBackupInfo: Found backup! memos=\(actualMemosCount), categories=\(actualCategoriesCount), deviceID=\(deviceID ?? "nil")")

            return (date, actualMemosCount, actualCategoriesCount, deviceID)
        } catch let ckError as CKError {
            os_log("❌ getBackupInfo: CKError %d - %{public}@", log: cloudKitLog, type: .error, ckError.code.rawValue, ckError.localizedDescription)
            print("❌ getBackupInfo: CKError \(ckError.code.rawValue) - \(ckError.localizedDescription)")
            return nil
        } catch {
            os_log("❌ getBackupInfo: Error - %{public}@", log: cloudKitLog, type: .error, error.localizedDescription)
            print("❌ getBackupInfo: Error - \(error.localizedDescription)")
            return nil
        }
    }

    /// バックアップを削除
    func deleteBackup() async -> Bool {
        let recordID = CKRecord.ID(recordName: primaryBackupRecordName)

        do {
            try await privateDatabase.deleteRecord(withID: recordID)
            print("✅ Backup deleted")
            lastBackupDate = nil
            UserDefaults.standard.removeObject(forKey: "lastCloudBackupDate")
            return true
        } catch {
            print("❌ Failed to delete backup: \(error)")
            return false
        }
    }

    /// バックアップの詳細診断（UI表示用）
    func diagnoseBackup() async -> String {
        var result = ""

        // iCloudアカウント確認
        let accountStatus = await checkiCloudAccountStatus()
        result += "iCloud: \(accountStatusDescription(accountStatus))\n"

        if accountStatus != .available {
            result += "⚠️ iCloudが利用できません"
            return result
        }

        let recordID = CKRecord.ID(recordName: primaryBackupRecordName)
        result += "RecordID: \(recordID.recordName)\n"

        do {
            let record = try await privateDatabase.record(for: recordID)

            // レコードのキーを確認
            let keys = record.allKeys()
            result += "Fields: \(keys.joined(separator: ", "))\n"

            // メタデータ
            let deviceID = record["deviceID"] as? String ?? "不明"
            let memosCount = record["memosCount"] as? Int64 ?? -1
            let categoriesCount = record["categoriesCount"] as? Int64 ?? -1
            let backupDate = record["lastBackupDate"] as? Date

            result += "DeviceID: \(deviceID)\n"
            result += "memosCount: \(memosCount)\n"
            result += "categoriesCount: \(categoriesCount)\n"
            if let date = backupDate {
                result += "Date: \(date)\n"
            }

            // memosDataの確認
            if let memosData = record["memosData"] as? Data {
                result += "\nmemosData: \(memosData.count) bytes\n"

                // デコードテスト
                let decoder = JSONDecoder()
                do {
                    let memos = try decoder.decode([QuickMemo].self, from: memosData)
                    result += "✅ メモデコード成功: \(memos.count)件\n"
                } catch {
                    result += "❌ メモデコード失敗: \(error.localizedDescription)\n"

                    // iso8601でも試す
                    let iso8601Decoder = JSONDecoder()
                    iso8601Decoder.dateDecodingStrategy = .iso8601
                    do {
                        let memos = try iso8601Decoder.decode([QuickMemo].self, from: memosData)
                        result += "✅ メモデコード成功(iso8601): \(memos.count)件\n"
                    } catch {
                        result += "❌ メモiso8601も失敗: \(error.localizedDescription)\n"

                        // 生データの先頭を表示
                        if let jsonString = String(data: memosData.prefix(200), encoding: .utf8) {
                            result += "Data preview: \(jsonString.prefix(100))...\n"
                        }
                    }
                }
            } else {
                result += "\n⚠️ memosData: なし\n"
            }

            // categoriesDataの確認
            if let categoriesData = record["categoriesData"] as? Data {
                result += "\ncategoriesData: \(categoriesData.count) bytes\n"

                // デコードテスト
                let decoder = JSONDecoder()
                do {
                    let categories = try decoder.decode([Category].self, from: categoriesData)
                    result += "✅ カテゴリーデコード成功: \(categories.count)件\n"
                } catch {
                    result += "❌ カテゴリーデコード失敗: \(error.localizedDescription)\n"

                    // 生データの先頭を表示
                    if let jsonString = String(data: categoriesData.prefix(200), encoding: .utf8) {
                        result += "Data preview: \(jsonString.prefix(100))...\n"
                    }
                }
            } else {
                result += "\n⚠️ categoriesData: なし\n"
            }

        } catch let ckError as CKError {
            if ckError.code == .unknownItem {
                result += "\n⚠️ バックアップレコードが存在しません"
            } else {
                result += "\n❌ CloudKitエラー: \(ckError.code.rawValue) - \(ckError.localizedDescription)"
            }
        } catch {
            result += "\n❌ エラー: \(error.localizedDescription)"
        }

        return result
    }
}