import Foundation
import CloudKit

/// CloudKitのスキーマ初期化をサポートするヘルパークラス
class CloudKitSchemaHelper {

    /// CloudKitのDevelopment環境にスキーマを作成するためのサンプルレコードを保存
    /// 注意: この関数は開発時のみ使用し、本番環境では使用しないこと
    static func createSchemaIfNeeded() async {
        #if DEBUG
        print("🔧 CloudKit Schema Helper: Starting schema initialization check")

        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase

        // テスト用レコードIDを作成
        let testRecordID = CKRecord.ID(recordName: "test_schema_record_\(UUID().uuidString)")
        let testRecord = CKRecord(recordType: "SubscriptionStatus", recordID: testRecordID)

        // 必要なフィールドを設定
        testRecord["userIdentifier"] = "test_user" as CKRecordValue
        testRecord["transactionID"] = "test_transaction" as CKRecordValue
        testRecord["productID"] = "test_product" as CKRecordValue
        testRecord["isPro"] = Int64(0) as CKRecordValue
        testRecord["lastUpdated"] = Date() as CKRecordValue
        testRecord["deviceID"] = "test_device" as CKRecordValue

        do {
            // レコードを保存してスキーマを作成
            _ = try await privateDatabase.save(testRecord)
            print("✅ CloudKit Schema Helper: Schema created/verified successfully")

            // テストレコードを削除
            _ = try await privateDatabase.deleteRecord(withID: testRecordID)
            print("✅ CloudKit Schema Helper: Test record cleaned up")

        } catch let error as CKError {
            switch error.code {
            case .unknownItem:
                print("⚠️ CloudKit Schema Helper: Record type might not exist yet")
            case .notAuthenticated:
                print("❌ CloudKit Schema Helper: Not authenticated to iCloud")
            case .permissionFailure:
                print("❌ CloudKit Schema Helper: Permission failure - check entitlements")
            case .networkUnavailable, .networkFailure:
                print("❌ CloudKit Schema Helper: Network issue - check connection")
            default:
                print("❌ CloudKit Schema Helper: Error creating schema: \(error.localizedDescription)")
            }
        } catch {
            print("❌ CloudKit Schema Helper: Unexpected error: \(error.localizedDescription)")
        }
        #endif
    }

    /// CloudKit Dashboardで必要なスキーマ設定を確認
    static func printSchemaRequirements() {
        print("""

        ================== CloudKit Schema Requirements ==================

        Record Type: SubscriptionStatus

        Required Fields:
        - userIdentifier (String)
        - transactionID (String)
        - productID (String)
        - isPro (Int64)
        - lastUpdated (Date/Time)
        - deviceID (String)

        Index Configuration:
        - Queryable: userIdentifier
        - Sortable: lastUpdated

        Security:
        - Record Security: User can read/write own records only

        To create in CloudKit Dashboard:
        1. Go to https://icloud.developer.apple.com/dashboard
        2. Select Container: iCloud.yokAppDev.quickMemoApp
        3. Choose Development environment
        4. Go to Schema → Record Types → Create New Type
        5. Name: SubscriptionStatus
        6. Add the fields listed above with correct types
        7. Save the schema

        ==================================================================
        """)
    }
}