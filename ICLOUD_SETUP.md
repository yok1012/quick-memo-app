# iCloud同期セットアップガイド

## 📱 現在の状態
- Core Dataの基本実装: ✅ 完了
- iCloud同期: ⏸️ 一時的に無効化（CloudKit設定待ち）
- タグ制限機能: ✅ 実装済み

## 🛠 修正した問題

### 1. Core Data Transformable属性のエラー
**問題**: `Declared Objective-C type "[String]" for attribute named defaultTags is not valid`

**原因**: Core DataのTransformable属性で`[String]`型を直接指定できない

**解決策**:
- `customClassName`を削除
- 属性を`NSObject?`として宣言
- 実行時にキャストして使用

### 2. CloudKitエラー
**問題**: `CloudKit push notifications require the 'remote-notification' background mode`

**原因**: CloudKitの必要な権限が不足

**解決策**: 一時的にCloudKit同期を無効化

## 📋 iCloud同期を有効にする手順

### 1. Xcode設定

#### Signing & Capabilities
1. プロジェクト設定を開く
2. **+ Capability** → **iCloud**を追加
3. 以下を有効化:
   - ✅ CloudKit
   - ✅ Key-value storage（オプション）

#### CloudKit Container
1. CloudKit Dashboardにアクセス
2. 新しいコンテナを作成: `iCloud.yokAppDev.quickMemoApp`
3. スキーマを作成（自動生成される）

#### Background Modes
1. **+ Capability** → **Background Modes**を追加
2. 以下を有効化:
   - ✅ Remote notifications

### 2. Info.plist設定
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### 3. コード変更

#### CoreDataStack.swift
```swift
// NSPersistentContainerをNSPersistentCloudKitContainerに戻す
lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "QuickMemoApp")

    // CloudKit設定
    guard let description = container.persistentStoreDescriptions.first else {
        fatalError("Failed to retrieve a persistent store description.")
    }

    description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

    // CloudKit Container設定
    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: "iCloud.yokAppDev.quickMemoApp"
    )

    container.loadPersistentStores { _, error in
        if let error = error {
            print("Core Data failed to load: \(error)")
        }
    }

    return container
}()
```

#### DataManager.swift
```swift
private func setupiCloudSync() {
    Task { @MainActor in
        iCloudSyncEnabled = purchaseManager.canUseiCloudSync() // コメントアウトを解除
        if iCloudSyncEnabled {
            print("✅ iCloud同期が有効になりました（Pro版）")
            await syncWithCoreData()
        }
    }
}
```

## 🧪 テスト方法

### ローカルテスト
1. シミュレーター2台を起動
2. 同じApple IDでサインイン
3. Pro版を有効化
4. メモを作成して同期を確認

### デバッグログ確認
```
✅ iCloud同期が有効になりました（Pro版）
📤 UserDefaultsからCore Dataへデータ移行開始
✅ データ移行完了: X件のメモ, Y件のカテゴリー
```

## ⚠️ 注意事項

1. **CloudKitコンテナID**: 本番環境では正しいコンテナIDを使用
2. **App Groups**: Widget/Watch連携のため維持必要
3. **データ移行**: UserDefaults → Core Dataは一度のみ実行
4. **Pro版制限**: 無料版はUserDefaultsのみ使用

## 📊 現在の制限

| 機能 | 無料版 | Pro版 |
|-----|--------|-------|
| メモ数 | 100個まで | 無制限 |
| タグ数/メモ | 15個まで | 無制限 |
| カテゴリー数 | 3個まで | 無制限 |
| iCloud同期 | ❌ | ✅ |
| Widget | 基本のみ | カスタマイズ可 |

## 🚀 今後の実装

1. CloudKit設定完了後、iCloud同期を再有効化
2. 競合解決ロジックの実装
3. オフライン時のキャッシュ処理
4. 同期状態のUI表示