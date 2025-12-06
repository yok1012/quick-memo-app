# QuickMemo データ保存・管理仕様書

本ドキュメントは、QuickMemoアプリのデータ保存に関する全ての技術仕様をまとめたものです。

## 目次

1. [概要](#1-概要)
2. [データ構造](#2-データ構造)
3. [ローカルストレージ](#3-ローカルストレージ)
4. [iCloud連携（Pro版機能）](#4-icloud連携pro版機能)
5. [Watch連携](#5-watch連携)
6. [Widget連携](#6-widget連携)
7. [データマイグレーション](#7-データマイグレーション)
8. [アプリ削除時の対応](#8-アプリ削除時の対応)
9. [アップデート時の対応](#9-アップデート時の対応)
10. [データ復旧機能](#10-データ復旧機能)
11. [エクスポート・インポート機能](#11-エクスポートインポート機能)
12. [制限事項](#12-制限事項)
13. [セキュリティとプライバシー](#13-セキュリティとプライバシー)
14. [トラブルシューティング](#14-トラブルシューティング)
15. [技術的詳細](#15-技術的詳細)

---

## 1. 概要

本アプリは**「オフラインファースト・高速起動」**を重視し、主たる保存領域として`UserDefaults`（App Group）を採用しています。Pro版ユーザー向けにはCloudKitを利用した**「バックアップと復元」**形式のクラウド同期を提供します。

### ストレージレイヤー一覧

| 保存領域 | 技術スタック | 目的 | 永続性 |
|:---|:---|:---|:---|
| **ローカル（iOS）** | UserDefaults (App Group) | メインデータ、Widget共有 | アプリ削除で消失 |
| **ローカル（Watch）** | UserDefaults (Standard) | Watch単独動作、キャッシュ | アプリ削除で消失 |
| **クラウド（Pro版）** | CloudKit (Private DB) | バックアップ、機種変更時の復元 | **永続（ユーザーが削除するまで）** |
| **Core Data** | Core Data (SQLite) | 現在未使用・将来のCloudKit連携用 | アプリ削除で消失 |

### データフロー図

```
ユーザー操作
    ↓
View (SwiftUI)
    ↓
DataManager (Singleton)
    ↓
┌───────────────────────────────────────────────┐
│              保存先                            │
├───────────────┬───────────────┬───────────────┤
│ App Group     │ CloudKit      │ Core Data     │
│ UserDefaults  │ (Pro版のみ)   │ (未使用)      │
│ ※必須        │ ※オプション  │ ※将来用      │
└───────────────┴───────────────┴───────────────┘
    ↓                   ↓
  Widget             iCloud
  Watch
```

---

## 2. データ構造

全てのデータ構造は`Codable`プロトコルに準拠し、JSONとしてシリアライズされます。後方互換性のためカスタムデコーダーを実装しています。

### 2.1 QuickMemo（メモ）

**ファイル**: `quickMemoApp/Models/DataModels.swift`

```swift
struct QuickMemo: Identifiable, Codable {
    let id: UUID                    // 一意識別子（自動生成）
    var title: String               // タイトル（空文字可、v1.1で追加）
    var content: String             // メモ内容
    var primaryCategory: String     // カテゴリー名
    var tags: [String]              // タグ配列
    var createdAt: Date             // 作成日時
    var updatedAt: Date             // 更新日時
    var calendarEventId: String?    // カレンダーイベントID（連携時のみ）
    var durationMinutes: Int        // カレンダーイベントの期間（分）、デフォルト30
}
```

**後方互換性**:
- `title`: 古いデータでは空文字`""`としてデコード
- `durationMinutes`: 古いデータでは`30`としてデコード

### 2.2 ArchivedMemo（削除履歴）

```swift
struct ArchivedMemo: Identifiable, Codable {
    let id: UUID                    // アーカイブID（自動生成）
    let originalMemo: QuickMemo     // 元のメモデータ（完全保持）
    let deletedAt: Date             // 削除日時
}
```

### 2.3 Category（カテゴリー）

```swift
struct Category: Identifiable, Codable {
    let id: UUID                    // 一意識別子（自動生成）
    var name: String                // カテゴリー名（ローカライズ済み）
    var icon: String                // SF Symbolsアイコン名
    var color: String               // 色（HEX形式、例: "007AFF"）
    var order: Int                  // 表示順序（0始まり）
    var defaultTags: [String]       // デフォルトタグ
    var isDefault: Bool             // デフォルトカテゴリーかどうか
    var baseKey: String?            // ローカライズ用ベースキー（例: "work"）
    var hiddenTags: Set<String>     // 非表示タグのセット
}
```

**後方互換性**:
- `isDefault`: 古いデータでは`false`としてデコード
- `baseKey`: 古いデータでは`nil`としてデコード
- `hiddenTags`: 古いデータでは空セット`[]`としてデコード

### 2.4 CloudKitレコード構造

#### DataBackup（データバックアップ）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `deviceID` | String | デバイス識別子（UDID） |
| `memosData` | Data | JSON encodedメモデータ（ISO8601日付） |
| `categoriesData` | Data | JSON encodedカテゴリーデータ |
| `memosCount` | Int64 | メモ数 |
| `categoriesCount` | Int64 | カテゴリー数 |
| `lastBackupDate` | Date | 最終バックアップ日時 |
| `appVersion` | String | アプリバージョン |

**レコードID**: `backup_{deviceID}`

#### SubscriptionStatus（購入状態）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `userIdentifier` | String | Sign in with Apple識別子 |
| `transactionID` | String | StoreKitトランザクションID |
| `productID` | String | 購入した商品ID |
| `isPro` | Int64 | Pro版フラグ（1 = Pro） |
| `lastUpdated` | Date | 最終更新日時 |
| `deviceID` | String | デバイス識別子 |

**レコードID**: `subscription_{userIdentifier}`

---

## 3. ローカルストレージ

### 3.1 iOS（App Group UserDefaults）

**Suite名**: `group.yokAppDev.quickMemoApp`

App Groupを使用することで、メインアプリとWidget間でデータを共有しています。グループが利用できない環境では標準`UserDefaults`にフォールバック。

```swift
let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
    self.userDefaults = groupDefaults
} else {
    self.userDefaults = UserDefaults.standard  // フォールバック
}
```

### UserDefaultsキー一覧（App Group）

| キー | 説明 | データ型 |
|------|------|----------|
| `memos` | メモデータ | JSON encoded `[QuickMemo]` |
| `categories` | カテゴリーデータ | JSON encoded `[Category]` |
| `categoriesBackup` | カテゴリーバックアップ | JSON encoded `[Category]` |
| `archivedMemos` | 削除履歴 | JSON encoded `[ArchivedMemo]` |
| `widgetCategories` | Widget表示カテゴリー | JSON encoded `[String]` |
| `isProVersion` | Pro版フラグ | `Bool` |
| `firstLaunchCompleted` | 初回起動完了フラグ | `Bool` |
| `dataMigrated` | マイグレーション完了フラグ | `Bool` |
| `appVersion` | アプリバージョン | `String` |
| `isPurchased` | 購入状態（Watch共有用） | `Bool` |

### UserDefaultsキー一覧（Standard）

| キー | 説明 | データ型 |
|------|------|----------|
| `lastCloudBackupDate` | 最終iCloudバックアップ日時 | `Date` |
| `NotificationEnabled` | 通知有効フラグ | `Bool` |
| `NotificationInterval` | 通知間隔 | `Int` |
| `QuietModeStart` | おやすみ開始時刻 | `Date` |
| `QuietModeEnd` | おやすみ終了時刻 | `Date` |
| `app_language` | アプリ言語設定 | `String` |
| `userIdentifier` | Sign in with Apple ID | `String` |
| `userEmail` | Sign in with Apple Email | `String` |
| `userName` | Sign in with Apple Name | `String` |
| `debugProMode` | デバッグPro有効（DEBUG） | `Bool` |

### 保存・読み込み処理

**保存処理**:
```swift
func saveMemos() {
    if let data = try? JSONEncoder().encode(memos) {
        userDefaults.set(data, forKey: memosKey)
        notifyWidgetUpdate()
    }
    if iCloudSyncEnabled {
        Task { await saveMemosToCoreData() }
    }
}

func saveCategories() {
    do {
        let data = try JSONEncoder().encode(categories)
        userDefaults.set(data, forKey: categoriesKey)
        userDefaults.set(data, forKey: categoriesBackupKey)  // バックアップも同時保存
        userDefaults.synchronize()
        notifyWidgetUpdate()
    } catch { /* エラーハンドリング */ }
}
```

**読み込み処理**:
```swift
func loadMemos() {
    if let data = userDefaults.data(forKey: memosKey),
       let decodedMemos = try? JSONDecoder().decode([QuickMemo].self, from: data) {
        memos = decodedMemos
    }
}
```

### 3.2 Core Data（現在未使用）

**ファイル**: `quickMemoApp/Services/CoreDataStack.swift`

Core Dataスタックは実装されていますが、現在はPro版でのミラー保存のみ。将来のCloudKit統合に備えて履歴トラッキングが有効化されています。

```swift
// 履歴トラッキングを有効化（将来のCloudKit統合のため）
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
```

**エンティティ**:
- `QuickMemoEntity`: メモエンティティ
- `CategoryEntity`: カテゴリーエンティティ

**ストア場所**: `Application Support/QuickMemoApp.sqlite`

---

## 4. iCloud連携（Pro版機能）

### 4.1 概要

Pro版ユーザーのみ、CloudKit（Private Database）を利用したデータバックアップと購入状態の同期が有効になります。

**ファイル**: `quickMemoApp/Services/CloudKitManager.swift`

### 4.2 CloudKit設定

- **コンテナID**: `iCloud.yokAppDev.quickMemoApp`（Bundle IDベース）
- **データベース**: Private Database（ユーザー固有、開発者もアクセス不可）

```swift
self.container = CKContainer.default()
self.privateDatabase = container.privateCloudDatabase
```

### 4.3 バックアップと復元

#### 自動バックアップのタイミング

1. **バックグラウンド移行時**: `UIApplication.willResignActiveNotification`受信時
   - 前回のバックアップから1時間以上経過していれば実行
2. **Pro版購入完了時**: 即時バックアップ

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(appWillResignActive),
    name: UIApplication.willResignActiveNotification,
    object: nil
)
```

#### 手動バックアップ・復元

設定画面から実行可能:
- `backupToiCloud()`: 現在のデータをiCloudにバックアップ
- `restoreFromiCloud()`: iCloudからデータを復元

#### 復元ロジック

```swift
func restoreData() async -> (memos: [QuickMemo], categories: [Category])? {
    // 1. 現在のデバイスのバックアップを検索
    let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    let recordID = CKRecord.ID(recordName: "backup_\(deviceID)")

    // 2. 見つからない場合、他のデバイスの最新バックアップを検索
    let query = CKQuery(recordType: backupRecordType, predicate: NSPredicate(value: true))
    query.sortDescriptors = [NSSortDescriptor(key: "lastBackupDate", ascending: false)]

    // 3. JSONデコードしてローカルに保存
}
```

### 4.4 購入状態の同期

Sign in with Appleでサインイン済みの場合のみ動作:

- **ローカルがPro、CloudKitに記録なし**: CloudKitにアップロード
- **CloudKitにPro記録あり**: ローカルをProに更新
- **サインアウト時**: `clearSubscriptionStatus()`でレコード削除

### 4.5 iCloud同期の条件

```swift
// 必須条件
guard purchaseManager.isProVersion else { return false }  // Pro版のみ

let accountStatus = await checkiCloudAccountStatus()
guard accountStatus == .available else { return false }   // iCloudサインイン必須
```

---

## 5. Watch連携

### 5.1 設計思想

| デバイス | 役割 |
|---------|------|
| iPhone | データのソースオブトゥルース（信頼できる単一情報源） |
| Watch | オフラインファースト、データをローカルにキャッシュ |

**ファイル**:
- iOS側: `quickMemoApp/Services/iOSWatchConnectivityManager.swift`
- Watch側: `quickMemoWatch Watch App/Services/WatchConnectivityManager.swift`
- Watch側データ: `quickMemoWatch Watch App/Services/WatchDataManager.swift`

### 5.2 Watchのデータモデル

**ファイル**: `quickMemoWatch Watch App/Models/WatchModels.swift`

iOS版より軽量化されたモデルを使用:

```swift
struct WatchMemo: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var category: String        // iOS版のprimaryCategoryに相当
    var createdAt: Date
    var tags: [String]
}

struct WatchCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var defaultTags: [String]
    var baseKey: String?
}
```

### 5.3 Watch UserDefaultsキー

| キー | 説明 | データ型 |
|------|------|----------|
| `watchMemos` | Watch用メモキャッシュ | JSON encoded `[WatchMemo]` |
| `watchCategories` | Watch用カテゴリーキャッシュ | JSON encoded `[WatchCategory]` |
| `pendingMemos` | 送信待ちメモキュー | `[[String: Any]]` |

### 5.4 同期フロー

#### iPhone → Watch

```
iPhone (iOSWatchConnectivityManager)
    ↓
sendCategoriesToWatch() / sendMemosToWatch()
    ↓
┌─────────────────────────────────────┐
│ 到達可能:  WCSession.sendMessage()  │
│ 到達不可: transferUserInfo()        │
└─────────────────────────────────────┘
    ↓
Watch (WatchConnectivityManager) で受信
    ↓
WatchDataManager に保存
```

**重要**: 最新20件のメモのみ同期（Watchの容量を考慮）

```swift
let memos = DataManager.shared.memos.prefix(20).map { ... }
```

#### Watch → iPhone

```
Watch でメモ作成
    ↓
WatchConnectivityManager.sendMemoToPhone()
    ↓
┌──────────────────────────────────────────┐
│ 到達可能:  WCSession.sendMessage()        │
│ 到達不可: pendingMemos に追加（キュー）   │
└──────────────────────────────────────────┘
    ↓
iPhone (iOSWatchConnectivityManager) で受信
    ↓
DataManager.addMemo() で保存
```

### 5.5 オフラインキュー

Watchは通信できない場合、メモを`pendingMemos`配列にキューイング:

```swift
private func storePendingMemo(_ memoData: [String: Any]) {
    pendingMemos.append(memoData)
    UserDefaults.standard.set(pendingMemos, forKey: "pendingMemos")
}

func syncPendingMemos() {
    guard !pendingMemos.isEmpty, WCSession.default.isReachable else { return }
    // キュー内のメモを送信...
}
```

接続復帰時（`sessionReachabilityDidChange`）に自動同期されます。

### 5.6 購入状態の同期

```swift
// iPhoneからWatchへ送信
let message: [String: Any] = [
    "type": "purchaseStatusUpdate",
    "isPro": isPro
]

// WatchはApp Groupにもキャッシュ
if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
    sharedDefaults.set(isPro, forKey: "isPurchased")
}
```

---

## 6. Widget連携

### 6.1 データ共有

**ファイル**: `quickMemoWidget/quickMemoWidget.swift`

App Group UserDefaultsを使用してメインアプリとWidgetでデータを共有。
Widgetは**読み取り専用**でデータにアクセスし、追加のストレージは持ちません。

### 6.2 Widget更新通知

データ変更時にWidgetの更新を通知:

```swift
private func notifyWidgetUpdate() {
    #if os(iOS)
    if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif
}
```

### 6.3 表示カテゴリー設定（Pro版）

```swift
func getWidgetCategories() -> [String]       // 表示カテゴリー取得
func saveWidgetCategories(_ categories: [String])  // 表示カテゴリー保存
func canCustomizeWidgetCategories() -> Bool  // カスタマイズ可能か（Pro版のみ）
```

Free版はデフォルト4件を表示。

---

## 7. データマイグレーション

### 7.1 自動マイグレーション

アプリ起動時に`DataManager.init()`で自動実行:

```swift
init() {
    // 1. App Group UserDefaultsの初期化
    // 2. データマイグレーション
    migrateDataFromOldLocations()
    // 3. データ読み込み
    loadCategories()
    loadMemos()
    // 4. 状態チェックと自動修復
    if categories.isEmpty && !memos.isEmpty {
        reconstructCategoriesFromMemos()
    }
}
```

### 7.2 マイグレーション対象

1. **標準UserDefaultsからApp Groupへ**
   - App Group entitlement追加前のデータを移行
   - 完了後`dataMigrated`フラグをセット

```swift
private func migrateFromStandardUserDefaults() -> Bool {
    let standard = UserDefaults.standard

    // カテゴリーのマイグレーション
    if userDefaults.data(forKey: categoriesKey) == nil,
       let legacyData = standard.data(forKey: categoriesKey) {
        userDefaults.set(legacyData, forKey: categoriesKey)
        userDefaults.set(legacyData, forKey: categoriesBackupKey)
    }

    // メモ、削除履歴、Widget設定、Pro状態のマイグレーション...
}
```

2. **カテゴリー再構築**
   - カテゴリーが消失した場合、メモから再構築

```swift
private func reconstructCategoriesFromMemos() {
    let categoryNames = Set(memos.map { $0.primaryCategory })
    for name in categoryNames {
        // カテゴリーを再作成
    }
}
```

3. **旧カテゴリーの変換**
   - 旧「shopping」カテゴリは「people」に変換

```swift
private func migrateLegacyShoppingCategory() {
    // "shopping" → "people" への変換処理
}
```

### 7.3 後方互換性の確保

カスタムデコーダーで新フィールドにデフォルト値を設定:

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // 必須フィールド
    id = try container.decode(UUID.self, forKey: .id)
    content = try container.decode(String.self, forKey: .content)

    // オプショナルフィールド（後方互換性）
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 30
    hiddenTags = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenTags) ?? []
}
```

---

## 8. アプリ削除時の対応

### 8.1 データの保持状況

| データ種別 | 削除後の状態 | 復旧方法 |
|-----------|-------------|---------|
| App Group UserDefaults | **削除される** | iCloudから復元（Pro版） |
| 標準UserDefaults | **削除される** | 復旧不可 |
| Core Data | **削除される** | 復旧不可 |
| iCloud（CloudKit） | **保持される** | 再インストール後に復元 |
| カレンダーイベント | **保持される** | アプリとの連携は切れる |

### 8.2 再インストール時の復旧

**Pro版ユーザー**:
1. App Storeから購入を復元
2. iCloudバックアップから自動復元（データが空の場合）
3. または設定画面から手動復元

**無料版ユーザー**:
- ローカルデータは復旧不可
- **推奨**: 削除前にエクスポート機能でバックアップを取得

### 8.3 CloudKitデータの完全削除

完全にデータを削除したい場合:
1. サインアウトで`SubscriptionStatus`レコード削除
2. 設定画面（デバッグ）から`deleteBackup()`でバックアップ削除

---

## 9. アップデート時の対応

### 9.1 データの保持

- UserDefaultsのデータは**そのまま保持**される
- データ構造の変更はカスタムデコーダーで吸収

### 9.2 バージョン毎のマイグレーション例

| バージョン | 変更内容 | 対応 |
|-----------|---------|------|
| v1.0 → v1.1 | `title`フィールド追加 | デフォルト空文字 |
| v1.1 → v1.2 | `hiddenTags`フィールド追加 | デフォルト空セット |
| v1.2 → v1.3 | `durationMinutes`追加 | デフォルト30分 |

### 9.3 デフォルトカテゴリーの補完

```swift
private func ensureDefaultCategoriesExist() {
    let defaultKeys = ["work", "personal", "idea", "people", "other"]
    for key in defaultKeys {
        if !categories.contains(where: { $0.baseKey == key }) {
            // 不足しているデフォルトカテゴリーを追加
        }
    }
}
```

### 9.4 Pro切り替え時の動作

- **Proになった時点**: 即時バックアップを実行
- **Pro失効時**: iCloud同期を停止（ローカル保存は継続）

---

## 10. データ復旧機能

### 10.1 自動復旧（起動時）

```swift
// カテゴリー消失時の自動修復
if categories.isEmpty && !memos.isEmpty {
    reconstructCategoriesFromMemos()
}

// バックアップからの復元
if categories.isEmpty {
    attemptCategoryRecovery()  // categoriesBackupキーから復元
}
```

### 10.2 手動復旧（設定画面から）

`attemptFullDataRecovery()`メソッド:

```swift
func attemptFullDataRecovery() -> (categories: Int, memos: Int) {
    // 1. 複数のUserDefaultsインスタンスをスキャン
    let possibleSuiteNames = [
        "group.yokAppDev.quickMemoApp",
        "yokAppDev.quickMemoApp",
        "com.yokAppDev.quickMemoApp"
    ]

    // 2. 件数が多いものを採用
    // 3. バックアップキーからの復元
    // 4. 削除履歴からのメモ復元
    // 5. メモからのカテゴリー再構築
}
```

---

## 11. エクスポート・インポート機能

**ファイル**: `quickMemoApp/Services/ExportManager.swift`

### 11.1 対応形式

| 形式 | 拡張子 | 特徴 |
|------|--------|------|
| CSV | `.csv` | Excelで開ける、UTF-8 BOM付き |
| JSON | `.json` | 完全なデータ構造を保持 |

### 11.2 エクスポート種別

| メソッド | 対象 | ファイル名 |
|---------|------|-----------|
| `exportMemos()` | 現在のメモ | `QuickMemo_YYYYMMDD_HHmmss.csv/json` |
| `exportArchivedMemos()` | 削除履歴 | `QuickMemo_Archive_YYYYMMDD_HHmmss.csv/json` |
| `exportAllData()` | 全データ | `QuickMemo_All_YYYYMMDD_HHmmss.csv/json` |

### 11.3 ファイル形式

#### CSV形式

```csv
ID,タイトル,内容,カテゴリー,タグ,作成日時,更新日時,カレンダーイベントID,期間(分)
uuid-string,タイトル,メモ内容,仕事,tag1;tag2,2024-01-01T00:00:00Z,...
```

**注意**: UTF-8 BOM付きでExcelでの日本語表示に対応

#### JSON形式

```json
{
  "exportDate": "2024-01-01T00:00:00Z",
  "version": "1.0",
  "memos": [
    {
      "id": "uuid-string",
      "title": "タイトル",
      "content": "メモ内容",
      "category": "仕事",
      "tags": ["tag1", "tag2"],
      "timestamp": "2024-01-01T00:00:00Z",
      "lastModified": "2024-01-01T00:00:00Z",
      "calendarEventId": null,
      "durationMinutes": 30
    }
  ]
}
```

### 11.4 インポート

```swift
func importMemos(from url: URL) throws -> [QuickMemo]
// - JSON/CSV両対応
// - 拡張子で自動判別
```

**出力先**: `FileManager.default.temporaryDirectory`（一時ファイル、永続保存はしない）

---

## 12. 制限事項

### 12.1 Free版の制限

| 項目 | Free版 | Pro版 |
|------|--------|-------|
| メモ数 | 100件 | 無制限 |
| カテゴリー数 | 5件 | 無制限 |
| メモあたりのタグ数 | 15件 | 無制限 |
| iCloud同期 | なし | あり |
| Widgetカスタマイズ | なし | あり |

### 12.2 技術的制限

| 項目 | 制限 | 備考 |
|------|------|------|
| UserDefaultsサイズ | 約1MB | パフォーマンス低下の目安 |
| Watch同期メモ数 | 20件 | 最新のものを優先 |
| CloudKitクォータ | Apple規定 | Private DBは比較的余裕あり |
| バックアップ間隔 | 1時間 | 自動バックアップの最小間隔 |

---

## 13. セキュリティとプライバシー

### 13.1 暗号化

- **ローカルデータ**: iOSファイルシステム暗号化で保護（パスコードロック時）
- **CloudKit**: Appleサーバー上で暗号化、開発者もアクセス不可（Private DB）

### 13.2 データ収集

- アプリ独自のサーバーへのデータ送信は**一切なし**
- 全てのユーザーデータはローカルまたはユーザーのiCloudに保存

### 13.3 カレンダー連携

- EventKitを使用
- カレンダーへのアクセス許可が必要
- イベントIDのみをメモに保存（カレンダーデータ自体はコピーしない）
- メモ削除時にカレンダーイベントも削除する場合は`CalendarService.deleteCalendarEvent`を呼び出す

---

## 14. トラブルシューティング

### 14.1 データが消えた場合

1. **設定 > データ復旧**を実行
2. **設定 > iCloudから復元**（Pro版）
3. エクスポートファイルがあればインポート

### 14.2 Watchと同期されない場合

1. iPhoneのWatchアプリでペアリング状態を確認
2. 両方のアプリを再起動
3. Watchアプリで「同期をリクエスト」

### 14.3 iCloudバックアップが失敗する場合

1. iCloudの空き容量を確認
2. iCloudアカウントのサインイン状態を確認
3. ネットワーク接続を確認
4. 設定 > Apple ID > iCloud でアプリの権限を確認

### 14.4 デバッグログの確認

```swift
// DataManager起動ログ
🔴 =====================================
🔴 DataManager init() called
🔴 =====================================
✅ Using App Group UserDefaults: group.yokAppDev.quickMemoApp
📊 After load: 5 categories
📊 After load: 10 memos
📋 DataManager initialization complete

// CloudKitデバッグ
CloudKitManager.shared.printDebugInfo()
// Container ID, Sync Status, Last Backup Date などを出力
```

---

## 15. 技術的詳細

### 15.1 関連ファイル

| ファイル | 役割 |
|---------|------|
| `quickMemoApp/Models/DataModels.swift` | データ構造の定義 |
| `quickMemoApp/Services/DataManager.swift` | データ操作の中心クラス |
| `quickMemoApp/Services/CloudKitManager.swift` | iCloud連携 |
| `quickMemoApp/Services/CoreDataStack.swift` | Core Data管理（現在未使用） |
| `quickMemoApp/Services/ExportManager.swift` | エクスポート・インポート |
| `quickMemoApp/Services/iOSWatchConnectivityManager.swift` | iOS側のWatch通信 |
| `quickMemoApp/Services/CalendarService.swift` | カレンダー連携 |
| `quickMemoApp/Services/AuthenticationManager.swift` | Sign in with Apple |
| `quickMemoWatch Watch App/Services/WatchConnectivityManager.swift` | Watch側の通信 |
| `quickMemoWatch Watch App/Services/WatchDataManager.swift` | Watch側のデータ管理 |
| `quickMemoWatch Watch App/Models/WatchModels.swift` | Watch用軽量データモデル |

### 15.2 通知名

| 通知名 | 用途 |
|--------|------|
| `PurchaseStatusChanged` | 購入状態変更時 |
| `OpenPurchaseView` | Watch→iPhone購入画面表示 |
| `OpenSettingsView` | Watch→iPhone設定画面表示 |

### 15.3 識別子一覧

| 識別子 | 値 |
|--------|-----|
| App Group | `group.yokAppDev.quickMemoApp` |
| Bundle ID | `yokAppDev.quickMemoApp` |
| CloudKit Container | `iCloud.yokAppDev.quickMemoApp` |

---

## 運用上の注意

1. **Free版ユーザー**: デバイス紛失時の復元手段がないため、重要データは定期的にエクスポート推奨

2. **CloudKitバックアップ**: 端末単位レコードのため、大量端末で使用すると最新バックアップが他端末のものになる可能性あり

3. **カレンダー連携**: ユーザーのカレンダー権限に依存、メモ削除時にイベントは自動削除されない（明示的に`deleteCalendarEvent`呼び出しが必要）

4. **エクスポート**: 一時ファイルとして出力されるため、共有後は自動削除される
