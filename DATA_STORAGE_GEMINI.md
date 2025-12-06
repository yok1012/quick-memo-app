# データ保存・管理仕様書 (Data Storage Specification)

本アプリ (`quickMemoApp`) のデータ保存、同期、ライフサイクル管理に関する詳細仕様を以下に定めます。

## 1. データ保存の概要 (Overview)

本アプリは **「オフラインファースト・高速起動」** を重視し、主たる保存領域として `UserDefaults` (App Group) を採用しています。Proユーザー向けには CloudKit を利用した **「バックアップと復元」** 形式のクラウド同期を提供します。

| 保存領域 | 技術スタック | 目的 | 永続性 |
| :--- | :--- | :--- | :--- |
| **ローカル (iOS)** | UserDefaults (App Group) | メインデータ、Widget共有 | アプリ削除で消失 |
| **ローカル (Watch)** | UserDefaults (Standard) | Watch単独動作、キャッシュ | App削除で消失 |
| **クラウド (Pro)** | CloudKit (Private DB) | バックアップ、機種変更時の復元 | **永続 (ユーザーが削除するまで)** |
| **Core Data** | Core Data (SQLite) | (現在未使用・将来の拡張用) | アプリ削除で消失 |

---

## 2. ローカルストレージ構造 (Local Storage)

### 2.1 iOSデバイス
*   **保存場所:** `UserDefaults`
*   **Suite Name:** `group.yokAppDev.quickMemoApp` (Widgetとデータを共有するため)
*   **主要キー:**
    *   `quick_memos`: メモ配列 (`[QuickMemo]`) のJSONデータ
    *   `categories`: カテゴリー配列 (`[Category]`) のJSONデータ
    *   `categories_backup`: カテゴリーデータの予備バックアップ
    *   `archived_memos`: 削除されたメモの履歴（ゴミ箱機能用）
    *   `widget_categories`: Widgetに表示するカテゴリー設定
    *   `is_pro_version`: Pro版課金状態のキャッシュ

#### マイグレーションと自己修復
アプリ起動時 (`DataManager.init`) に以下の処理を自動実行します：
1.  **レガシー移行:** 標準 `UserDefaults` から App Group へのデータ移行。
2.  **自己修復:** カテゴリーデータが消失している場合、メモデータ内に残るカテゴリー情報から自動でカテゴリーを再構築 (`reconstructCategoriesFromMemos`)。

### 2.2 watchOSデバイス
*   **保存場所:** `UserDefaults.standard`
*   **主要キー:**
    *   `watchMemos`: Watch上のメモキャッシュ
    *   `watchCategories`: カテゴリーキャッシュ
*   **同期:** iOSアプリから `WatchConnectivity` 経由でデータを受け取り、ローカルに保存します。これによりiPhoneが近くにない状態でも閲覧・入力が可能です。

---

## 3. iCloud連携 (CloudKit - Pro Feature)

Pro版ユーザーのみ、CloudKit (Private Database) を利用したデータバックアップとサブスクリプション状態の同期が有効になります。

*   **コンテナ:** `iCloud.yokAppDev.quickMemoApp` (Default Container)
*   **同期方式:** **JSON一括バックアップ方式** (レコード単位の同期ではなく、全データをJSON化して1つのレコードとして保存)

### 3.1 保存されるレコードタイプ (Record Types)

| Record Type | フィールド | 用途 |
| :--- | :--- | :--- |
| `DataBackup` | `memosData` (JSON)<br>`categoriesData` (JSON)<br>`deviceID`<br>`lastBackupDate` | 全データのバックアップ。機種変更や再インストール時の復元に使用。 |
| `SubscriptionStatus` | `isPro` (Int64)<br>`transactionID`<br>`expirationDate` | 複数デバイス間でのPro権限の共有・確認用。 |

### 3.2 バックアップと復元のトリガー
*   **自動バックアップ:** アプリがバックグラウンドに移行した際、前回のバックアップから1時間以上経過していれば実行。
*   **手動バックアップ/復元:** 設定画面からユーザーが明示的に実行可能。
*   **初回起動時の復元:** 新規インストール後、データが空の状態でPro権限が確認された場合、iCloudからの自動復元を試みます。

---

## 4. データモデル構造 (Data Models)

`Codable` プロトコルに準拠し、JSONとしてシリアライズされます。将来的なフィールド追加に備え、カスタムデコーダー (`init(from decoder:)`) で後方互換性を担保しています。

### 4.1 QuickMemo (メモ)
```swift
struct QuickMemo: Identifiable, Codable {
    let id: UUID
    var title: String          // タイトル
    var content: String        // 本文
    var primaryCategory: String // カテゴリー名
    var tags: [String]         // タグ配列
    var createdAt: Date        // 作成日時
    var updatedAt: Date        // 更新日時
    var calendarEventId: String? // 連携したカレンダーイベントID
    var durationMinutes: Int   // イベント期間（分）
}
```

### 4.2 Category (カテゴリー)
```swift
struct Category: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String           // SF Symbols名
    var color: String          // Hexカラーコード
    var order: Int             // 表示順序
    var isDefault: Bool        // デフォルトカテゴリーフラグ
    var baseKey: String?       // 多言語対応用のキー (e.g., "work")
    var hiddenTags: Set<String> // このカテゴリーで非表示にするタグ
}
```

---

## 5. ライフサイクル対応 (Lifecycle Events)

### 5.1 アプリ削除時 (App Deletion)
*   **ローカルデータ:** アプリ本体と共に `UserDefaults` (App Group含む) は**完全に削除**されます。
*   **iCloudデータ:** ユーザーのPrivate Databaseにあるため、**削除されずに残ります**。再インストール後に「設定 > iCloudから復元」を行うことでデータを復旧できます。

### 5.2 アプリ・アップデート時 (App Update)
*   `UserDefaults` のデータは保持されます。
*   データ構造に変更がある場合（例: 新しいプロパティの追加）、`Codable` の `init(from:)` 内でデフォルト値を設定することで、古いデータ構造からの安全な読み込みを保証しています。

### 5.3 機種変更時 (Device Migration)
1.  **クイックスタート復元:** iOSのバックアップ復元を利用する場合、ローカルデータ (`UserDefaults`) もそのまま新しい端末に移行されます。
2.  **手動セットアップ:** 新しい端末でアプリをDLした場合、データは空の状態です。「設定 > iCloudから復元」を実行することで、旧端末で作成したバックアップをダウンロードできます (Pro版のみ)。

---

## 6. セキュリティとプライバシー (Security)

*   **暗号化:** ローカルデータはiOS標準のファイルシステム暗号化で保護されます（パスコードロック時）。
*   **CloudKit:** データはAppleのサーバー上で暗号化されて保存され、開発者も閲覧することはできません（Private Database）。
*   **データ収集:** アプリ自体が独自のサーバーにデータを送信することはありません。
