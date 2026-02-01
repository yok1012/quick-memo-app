# CloudKit Database 確認ガイド

## 1. CloudKit Dashboardへアクセス

1. **URL**: https://icloud.developer.apple.com/dashboard
2. Apple Developer アカウントでサインイン
3. アプリ一覧から「quickMemoApp」を選択

## 2. Container設定の確認

### 現在の設定
- **Container ID**: `iCloud.yokAppDev.quickMemoApp`（推奨）
- または デフォルト: `iCloud.com.yourcompany.quickMemoApp`（要変更）

⚠️ **注意**: CloudKitManager.swiftの実装では`CKContainer.default()`を使用しているため、プロジェクトのBundle IDに基づいたコンテナが使用されます。

## 3. Schema（スキーマ）の確認

### Development環境で確認

1. 左メニューから「Schema」を選択
2. 「Record Types」タブを選択
3. 以下のレコードタイプが存在するか確認：

#### SubscriptionStatus レコードタイプ
| Field Name | Field Type | Required |
|------------|------------|----------|
| userIdentifier | String | Yes |
| transactionID | String | Yes |
| productID | String | Yes |
| isPro | Int64 | Yes |
| lastUpdated | Date/Time | Yes |
| deviceID | String | No |

## 4. データの確認方法

### Development環境でのデータ確認

1. 左メニューから「Data」を選択
2. 「Records」タブを選択
3. Record Type: `SubscriptionStatus`を選択
4. 「Query Records」をクリック

### 確認できる情報

- **Record Name**: `subscription_[userIdentifier]`
- **Created**: レコード作成日時
- **Modified**: 最終更新日時
- **Fields**: 各フィールドの値

## 5. トラブルシューティング

### データが表示されない場合

#### 1. コンテナIDの確認
```bash
# Xcodeプロジェクトで確認
1. プロジェクトナビゲータでプロジェクトを選択
2. Signing & Capabilities
3. CloudKit capability
4. Containersで使用中のコンテナを確認
```

#### 2. 環境の確認
- Development環境でテスト中のデータは、Production環境には表示されません
- Production環境にデプロイするには：
  1. CloudKit Dashboard → Schema → Deploy to Production

#### 3. 権限の確認
- ユーザーがiCloudにサインインしているか
- アプリにCloudKit使用権限があるか

### CloudKitManager.swiftの修正が必要な場合

現在の実装:
```swift
self.container = CKContainer.default()
```

特定のコンテナを使用する場合:
```swift
self.container = CKContainer(identifier: "iCloud.yokAppDev.quickMemoApp")
```

## 6. Xcode経由でのデバッグ

### CloudKit Debugger（Xcodeコンソール）

```swift
// デバッグ用コードを追加
print("Container ID: \(container.containerIdentifier ?? "unknown")")
print("Database: \(privateDatabase)")
```

### 実機テストでの確認

1. 実機でアプリを起動
2. Sign in with Appleでサインイン
3. 購入または購入復元を実行
4. CloudKit Dashboardで即座に確認可能

## 7. セキュリティとプライバシー

### プライベートデータベース
- 各ユーザーのデータは隔離されている
- 開発者もユーザーの個人データは見られない（開発環境のテストデータのみ）

### Public vs Private Database
- **Private Database**: ユーザー固有のデータ（購入情報など）
- **Public Database**: 全ユーザー共有データ（使用していない）

## 8. よくある問題と解決策

### Q: レコードが作成されない
A: 以下を確認：
- iCloudサインイン状態
- CloudKit capability有効化
- ネットワーク接続
- CKAccountStatusが.availableか

### Q: 他デバイスで同期されない
A: 以下を確認：
- 同じApple IDでサインイン
- 同じuserIdentifierを取得しているか
- CloudKitの同期遅延（数秒〜数分）

### Q: Production環境にデータがない
A: Development → Productionへのスキーマデプロイが必要

## 9. コマンドラインツール（オプション）

CloudKit Web Servicesを使用したAPI経由の確認も可能：
- CloudKit JS
- CloudKit Web Services API

詳細: https://developer.apple.com/documentation/cloudkitjs