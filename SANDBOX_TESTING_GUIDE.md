# Sandbox購入テストガイド

## デバッグツールの使用方法

### 1. デバッグメニューへのアクセス
設定画面 → 一番下にスクロール → 「デバッグツール」セクション（DEBUG環境のみ表示）

### 2. 購入状態のリセット手順

#### 完全リセット（推奨）
1. **設定 → デバッグツール**
2. 以下を順番に実行：
   - 「購入状態をリセット」をタップ
   - 「CloudKitレコードを削除」をタップ（サインイン中の場合）
   - 「Sandboxトランザクションをクリア」をタップ

#### 手動でPro版をテスト
1. **設定 → デバッグツール**
2. 「Pro版モード（テスト用）」をON/OFFで切り替え
   - ON: Pro版として動作（購入なしでテスト可能）
   - OFF: 無料版として動作

### 3. CloudKitデータの再テスト

#### 新規購入フローのテスト
```
1. デバッグ情報を出力（現在の状態確認）
2. 購入状態をリセット
3. CloudKitレコードを削除
4. Sandboxトランザクションをクリア
5. アプリを再起動
6. Sign in with Appleでサインイン
7. 購入画面から再度購入
8. コンソールでCloudKit保存ログを確認
```

#### CloudKitデータ同期の確認
```
1. デバッグ情報を出力
2. CloudKit Dashboardで確認
3. Development環境 → SubscriptionStatusレコード
```

## コンソールログの確認ポイント

### 成功パターン
```
🔧 CloudKit Schema Helper: Schema created/verified successfully
🔍 iCloud Available at startup: true
🔐 AuthenticationManager: Sign in with Apple success
🔄 CloudKit: saveSubscriptionStatus started
✅ Record saved successfully
✅ CloudKit: saveSubscriptionStatus completed successfully
```

### エラーパターン
```
❌ CloudKit Error: Not authenticated to iCloud
❌ CloudKit Error: Network unavailable
❌ CloudKit Error: Permission failure
```

## Xcode側のSandbox設定

### StoreKit Configuration
1. **Product → Scheme → Edit Scheme**
2. **Run → Options → StoreKit Configuration**
3. Configuration fileを選択（ない場合は作成）

### Sandbox アカウント
1. **App Store Connect → ユーザーとアクセス → Sandbox**
2. テスター追加（異なるメールアドレス使用）
3. デバイスの設定 → App Store → Sandboxアカウント

## トラブルシューティング

### 購入状態が残っている場合
```bash
# デバイスの設定で対処
1. 設定 → App Store → Sandboxアカウント → サインアウト
2. アプリを削除・再インストール
3. 新しいSandboxアカウントでサインイン
```

### CloudKitデータが残っている場合
```bash
# CloudKit Dashboardで直接削除
1. https://icloud.developer.apple.com/dashboard
2. Container: iCloud.yokAppDev.quickMemoApp
3. Development → Data → Query Records
4. Record Type: SubscriptionStatus
5. 該当レコードを選択して削除
```

### トランザクションが完了しない場合
```swift
// デバッグメニューから実行
1. 「Sandboxトランザクションをクリア」
2. 「デバッグ情報を出力」でトランザクション確認
3. コンソールで未完了トランザクションを確認
```

## テストシナリオ

### シナリオ1: 新規購入
1. リセット → サインイン → 購入 → CloudKit確認

### シナリオ2: 復元
1. リセット → サインイン → 購入を復元 → CloudKit確認

### シナリオ3: 別デバイス同期
1. デバイスA: 購入 → CloudKit保存
2. デバイスB: サインイン → CloudKitから復元

### シナリオ4: オフライン→オンライン
1. 機内モードON → 購入試行
2. 機内モードOFF → 自動同期確認

## デバッグ出力の見方

```
========== デバッグ情報 ==========
📱 App Info:
  - Pro版: false/true
  - UserDefaults isProVersion: false/true

👤 Authentication:
  - サインイン状態: false/true
  - ユーザーID: XXXXX-XXXX-XXXX または nil

☁️ CloudKit:
  Container ID: iCloud.yokAppDev.quickMemoApp
  Record Type: SubscriptionStatus
  Is Syncing: false/true
  Last Sync Date: 2025-10-07 10:00:00 +0000 または never
  Sync Error: none または エラーメッセージ

💰 StoreKit:
  - 現在のエンタイトルメント:
    • ID: 2000000XXXXX
      Product: com.yokAppDev.quickMemoApp.pro.month
      Date: 2025-10-07 10:00:00 +0000
      Revoked: false/true
==================================
```

## 注意事項

- デバッグツールはDEBUG環境でのみ表示されます
- 本番環境では自動的に非表示になります
- Sandboxトランザクションは24時間で自動リセットされることがあります
- CloudKit Developmentデータは本番環境には影響しません