# CloudKitコンテナ作成ガイド

## 方法1: Xcodeで自動作成（推奨）

### 1. Xcodeでプロジェクトを開く
1. `quickMemoApp.xcodeproj`を開く
2. プロジェクトナビゲータで`quickMemoApp`プロジェクトを選択
3. `quickMemoApp`ターゲットを選択

### 2. CloudKit Capabilityを追加
1. **Signing & Capabilities**タブを選択
2. 「+ Capability」ボタンをクリック
3. 「CloudKit」を検索して追加

### 3. コンテナの設定
CloudKitが追加されると、以下のオプションが表示されます：

#### オプション1: デフォルトコンテナを使用（最も簡単）
```
☑️ Use default container
```
これを選択すると、自動的に`iCloud.yokAppDev.quickMemoApp`が作成されます

#### オプション2: カスタムコンテナを指定
```
☐ Use default container
☑️ Specify custom containers
   + Add Container
```
「+ Add Container」をクリックして`iCloud.yokAppDev.quickMemoApp`を入力

### 4. 自動的に作成されるもの
- CloudKitコンテナ
- Entitlementsファイルへの追加
- App IDへのCloudKit機能の追加

## 方法2: Apple Developer Portalで手動作成

### 1. Apple Developer Portalにアクセス
https://developer.apple.com/account

### 2. Certificates, Identifiers & Profilesへ
1. 「Certificates, IDs & Profiles」を選択
2. 「Identifiers」を選択
3. 「yokAppDev.quickMemoApp」を見つける

### 3. CloudKit機能を有効化
1. App IDを選択
2. 「Capabilities」セクションで「CloudKit」にチェック
3. 「Save」をクリック

### 4. CloudKit Containerを作成
1. 左メニューから「CloudKit Containers」を選択
2. 「+」ボタンをクリック
3. Container ID: `iCloud.yokAppDev.quickMemoApp`を入力
4. 「Continue」→「Register」

## CloudKit Dashboardでスキーマを設定

### 1. CloudKit Dashboardにアクセス
https://icloud.developer.apple.com/dashboard

### 2. コンテナを選択
作成した`iCloud.yokAppDev.quickMemoApp`を選択

### 3. Development環境でRecord Typeを作成

#### Schema → Record Types → 「+」をクリック

**Record Type名**: `SubscriptionStatus`

**Fields**を追加:
| Field Name | Type | Options |
|------------|------|---------|
| userIdentifier | String | Queryable, Sortable |
| transactionID | String | Queryable |
| productID | String | Queryable |
| isPro | Int64 | Queryable |
| lastUpdated | Date/Time | Queryable, Sortable |
| deviceID | String | - |

### 4. インデックスを作成（オプション）
Schema → Indexes → 「+」
- Index Name: `userIdentifierIndex`
- Record Type: `SubscriptionStatus`
- Field: `userIdentifier`
- Type: `QUERYABLE`

## コード側の設定確認

### CloudKitManager.swiftの確認

```swift
// 現在の実装（デフォルトコンテナを使用）
self.container = CKContainer.default()

// 明示的に指定する場合
self.container = CKContainer(identifier: "iCloud.yokAppDev.quickMemoApp")
```

### Info.plistの確認（自動生成される場合が多い）

```xml
<key>CKSharingSupported</key>
<true/>
```

## テスト手順

### 1. ビルド設定の確認
1. Xcodeでビルド
2. エラーがないことを確認

### 2. 実機/シミュレータでテスト
```swift
// デバッグログの確認
CloudKit Container ID: iCloud.yokAppDev.quickMemoApp
```

### 3. CloudKit Dashboardで確認
1. Data → Private Database
2. Record Type: `SubscriptionStatus`
3. Query Recordsでデータ確認

## トラブルシューティング

### エラー: "Container not found"
**原因**: コンテナが作成されていない
**解決**: Xcodeで「+ Capability」→「CloudKit」を追加

### エラー: "Not Authenticated"
**原因**: iCloudにサインインしていない
**解決**: 設定 → iCloud → サインイン

### エラー: "Permission Denied"
**原因**: Entitlementsが正しく設定されていない
**解決**:
1. プロジェクト設定でCloudKitを再追加
2. Clean Build Folder（Shift+Cmd+K）
3. 再ビルド

### エラー: "Schema not found"
**原因**: Record Typeが作成されていない
**解決**: CloudKit Dashboardで手動作成

## Production環境へのデプロイ

### Development → Production
1. CloudKit Dashboard → Schema
2. 「Deploy Schema Changes...」
3. Record Typesを選択
4. 「Deploy to Production」

⚠️ **重要**: Production環境にデプロイ後は、スキーマの削除や変更に制限があります

## 確認チェックリスト

- [ ] Xcodeでビルドエラーがない
- [ ] CloudKit Capabilityが有効
- [ ] コンテナIDがコンソールに出力される
- [ ] CloudKit DashboardでRecord Typeが見える
- [ ] テストデータの作成・取得が成功する
- [ ] Sign in with Apple → 購入 → CloudKitにデータが保存される