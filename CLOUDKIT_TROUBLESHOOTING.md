# CloudKitデータ登録問題のトラブルシューティング

## 実機でのテスト手順

### 1. 実機の事前準備

1. **設定アプリで確認**
   - 設定 → [自分の名前] → iCloud
   - 「iCloud」がオンになっているか確認
   - 「iCloudを使用しているAPP」で「quickMemoApp」を探す
   - なければ、リストの一番下までスクロール

2. **iCloudストレージ確認**
   - 設定 → [自分の名前] → iCloud → ストレージを管理
   - 空き容量があることを確認

3. **ネットワーク接続**
   - Wi-Fiまたはモバイルデータがオンになっているか確認

### 2. Xcodeでのデバッグ

1. **実機を接続**
   ```
   Xcode → Window → Devices and Simulators
   実機が表示されることを確認
   ```

2. **実機でビルド**
   - Scheme: quickMemoApp
   - Device: 自分のiPhone
   - Product → Run (Cmd+R)

3. **コンソールログを確認**
   - View → Debug Area → Show Debug Area
   - 以下のログを確認：

   ```
   CloudKit Container ID: iCloud.yokAppDev.quickMemoApp
   🔐 AuthenticationManager: Sign in with Apple success
   🔄 CloudKit: syncSubscriptionStatus started
   🔄 CloudKit: saveSubscriptionStatus started
   ```

### 3. アプリ内でのテスト手順

1. **Sign in with Appleテスト**
   ```
   1. Settings → Account → Sign in with Apple
   2. Apple IDでサインイン
   3. コンソールで以下を確認：
      - User ID: XXXXX-XXXX-XXXX
      - ✅ Sign in completed
   ```

2. **購入テスト（Sandbox）**
   ```
   1. Settings/購入画面 → Pro版を購入
   2. Sandboxアカウントで購入
   3. コンソールで以下を確認：
      - TransactionID: 200000XXXXXX
      - ProductID: com.yokAppDev.quickMemoApp.pro.month
      - ✅ Record saved successfully
   ```

### 4. CloudKit Dashboardで確認

1. https://icloud.developer.apple.com/dashboard
2. Container: `iCloud.yokAppDev.quickMemoApp`
3. Data → Private Database → Query Records
4. Record Type: `SubscriptionStatus`を選択
5. Query Records実行

## トラブルシューティング

### 問題1: "Container not found"

**原因**: CloudKitコンテナが作成されていない

**解決方法**:
```bash
# Xcodeで確認
1. プロジェクト設定 → Signing & Capabilities
2. CloudKit capability確認
3. Container: iCloud.yokAppDev.quickMemoAppが選択されているか
```

### 問題2: "Not authenticated to iCloud"

**原因**: iCloudにサインインしていない

**解決方法**:
```
1. 設定 → [自分の名前]でiCloudにサインイン
2. アプリを完全に終了して再起動
3. 再度Sign in with Appleを実行
```

### 問題3: "Network unavailable"

**原因**: ネットワーク接続問題

**解決方法**:
```
1. 機内モードをオフにする
2. Wi-Fi/モバイルデータを確認
3. 他のアプリでネットワーク接続を確認
```

### 問題4: データが保存されるがDashboardに表示されない

**原因**: Development/Production環境の不一致

**確認項目**:
```
1. CloudKit Dashboard → Development環境を選択
2. スキーマがDevelopmentに存在するか確認
3. Xcodeのビルド設定がDebugになっているか確認
```

### 問題5: "Permission failure"

**原因**: アプリにCloudKit権限がない

**解決方法**:
```
1. 設定 → quickMemoApp → iCloudをオン
2. プロジェクトのentitlementsファイルを確認
3. iCloud container identifiersが正しく設定されているか
```

## デバッグ用コードの追加

### AppDelegate/SceneDelegateに追加
```swift
// アプリ起動時にCloudKit状態を確認
Task {
    await CloudKitManager.shared.printDebugInfo()
    let isAvailable = await CloudKitManager.shared.isiCloudAvailable()
    print("iCloud Available: \(isAvailable)")
}
```

### PurchaseManagerに追加
```swift
// 購入完了時にCloudKit保存を確認
case .purchased:
    print("📱 Purchase completed, saving to CloudKit...")
    if AuthenticationManager.shared.isSignedIn {
        await CloudKitManager.shared.saveSubscriptionStatus(
            transactionID: String(transaction.id),
            productID: transaction.productID
        )
    }
```

## コンソールログの確認ポイント

### 成功時のログ
```
🔄 CloudKit: saveSubscriptionStatus started
  - TransactionID: 2000000XXXXX
  - ProductID: com.yokAppDev.quickMemoApp.pro.month
  - UserIdentifier: XXXXX-XXXX-XXXX
  - iCloud Account Status: 1 (available)
  - RecordID: subscription_XXXXX-XXXX-XXXX
  ✅ Creating new record
  📝 Record fields set:
    - userIdentifier: XXXXX-XXXX-XXXX
    - transactionID: 2000000XXXXX
    - productID: com.yokAppDev.quickMemoApp.pro.month
    - isPro: 1
    - deviceID: XXXXXXXX-XXXX-XXXX
  ✅ Record saved successfully
✅ CloudKit: saveSubscriptionStatus completed successfully
```

### 失敗時のログ例
```
❌ CloudKit Error: iCloud account not available: 3
❌ CloudKit Error: Not authenticated to iCloud
❌ CloudKit Error: Network unavailable
❌ CloudKit Error: Permission failure
```

## テストチェックリスト

- [ ] iCloudにサインインしている
- [ ] アプリがiCloudを使用する権限を持っている
- [ ] ネットワーク接続が有効
- [ ] CloudKit Container IDが正しい
- [ ] Sign in with Appleが成功している
- [ ] 購入/復元が成功している
- [ ] コンソールログにエラーがない
- [ ] CloudKit Dashboardでレコードが確認できる

## 🆕 実装された修正事項（2025-10-07）

### 修正1: データ型の互換性問題
- `isPro`フィールドをInt64型として明示的に設定
- すべてのフィールドでCKRecordValue型キャストを追加
- 読み取り時もInt64として適切に処理

### 修正2: スキーマ自動作成ヘルパー
- CloudKitSchemaHelperクラスを追加
- Debug環境でスキーマを自動的に初期化
- アプリ起動時にiCloud利用可能性をチェック

### 修正3: エンハンスドデバッグログ
- iCloudアカウントステータスの詳細なログ出力
- 各フィールドの値をログに記録
- CloudKitエラーコードの詳細な解析

## Development → Production移行時の注意

1. **スキーマのデプロイ**
   ```
   CloudKit Dashboard → Schema → Deploy to Production
   ```

2. **Xcodeビルド設定**
   ```
   Build Configuration: Release
   Archive → Upload to App Store
   ```

3. **テスト**
   - TestFlightでProduction環境をテスト
   - CloudKit Dashboard → Productionでデータ確認