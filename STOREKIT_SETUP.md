# StoreKit設定ガイド

## 問題の診断と解決方法

### 1. Product IDの確認
現在の設定: `yokAppDev.quickMemoApp.pro`

**確認手順:**
1. App Store Connectにログイン
2. アプリを選択 → App内課金 → 管理
3. Product IDが正確に一致していることを確認
4. ステータスが「Ready to Submit」または「Approved」になっているか確認

### 2. Xcodeでの設定

#### StoreKit Configurationファイルの使用
1. Xcode → Product → Scheme → Edit Scheme
2. Run → Options タブ
3. StoreKit Configuration: `StoreKitConfiguration.storekit`を選択

#### Sandboxテストアカウント
1. App Store Connect → ユーザとアクセス → Sandboxテスター
2. 新しいテストアカウントを作成（実際のApple IDとは別のメール必須）
3. デバイスの設定 → App Store → サインアウト
4. テスト購入時にSandboxアカウントでサインイン

### 3. よくある問題と解決策

#### 問題1: Product IDが見つからない
```
❌ Failed to load products: No products were found
```

**解決策:**
- Product IDが正確に一致しているか確認
- App Store Connectで商品が有効になっているか確認
- Bundle IDが一致しているか確認

#### 問題2: 復元しても購入履歴が見つからない
```
⚠️ No purchases found to restore
```

**解決策:**
1. 同じSandboxアカウントで購入したか確認
2. Sandboxサーバーの同期待ち（数分かかることがある）
3. デバイスのネットワーク接続を確認

#### 問題3: Transaction検証エラー
```
❌ Unverified transaction
```

**解決策:**
- Xcodeを再起動
- StoreKit Configurationファイルをリセット
- デバイスを再起動

### 4. デバッグ用ログの確認

コンソールで以下のログを確認:
```
🔄 Starting restore purchases...
✅ AppStore.sync() completed
📋 Updating purchased products...
📊 Total transactions checked: X
🎯 Pro version status: true/false
```

### 5. テスト手順

1. **初回購入テスト**
   - アプリを起動
   - 設定 → QuickMemo Proをタップ
   - 購入ボタンをタップ
   - Sandboxアカウントでサインイン
   - 購入を完了

2. **復元テスト**
   - アプリをアンインストール/再インストール
   - 設定 → QuickMemo Proをタップ
   - 「購入を復元」をタップ
   - 同じSandboxアカウントでサインイン
   - Pro機能が有効になることを確認

### 6. 本番環境への移行

1. App Store Connectで商品を承認申請
2. アプリ審査時にIn-App Purchaseも含める
3. StoreKit Configurationファイルを削除（本番では不要）
4. Schemeから StoreKit Configurationの選択を解除

### 7. トラブルシューティングチェックリスト

- [ ] Product IDが正確に一致している
- [ ] App Store Connectで商品が有効
- [ ] Bundle IDが一致している
- [ ] Sandboxアカウントを使用している
- [ ] ネットワーク接続が正常
- [ ] StoreKit Configurationが正しく設定されている
- [ ] Capabilitiesで In-App Purchaseが有効
- [ ] App Groupsが正しく設定されている

### 8. デバッグモードの使用

開発時はデバッグモードでPro機能をテスト可能:

```swift
#if DEBUG
PurchaseManager.shared.enableDebugMode()
PurchaseManager.shared.forceProVersion = true
#endif
```

## 実装済みの改善点

1. **詳細なログ出力** - すべてのStoreKit操作で詳細ログを出力
2. **エラーハンドリング強化** - 復元失敗時の詳細なエラー情報
3. **トランザクション確認** - すべてのトランザクションを個別に確認
4. **App Group同期** - Watch/Widget用にPro状態を保存

## 次のステップ

1. App Store ConnectでProduct IDを確認
2. Sandboxテストアカウントで再テスト
3. コンソールログを確認して問題を特定
4. 必要に応じてProduct IDを修正