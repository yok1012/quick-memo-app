# Sandbox "Unable to Complete Request" エラーの解決方法

## エラーの原因と解決策

### 1. すぐに確認すべき項目

#### A. App Store Connect の設定
1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. 「契約/税金/銀行業務」を確認
   - **有料アプリ契約が有効になっているか確認**（これが最も一般的な原因）
   - すべての必要な税務情報が提出されているか
   - 銀行口座情報が設定されているか

#### B. Product ID の確認
```
現在設定されているProduct ID:
- yokAppDev.quickMemoApp.pro
- pro.quickmemo.monthly
- com.yokAppDev.quickMemoApp.pro
```

App Store Connectで：
1. マイApp → あなたのアプリ → App内課金 → 管理
2. 製品IDが上記のいずれかと**完全に一致**しているか確認
3. ステータスが「提出準備完了」になっているか確認

#### C. Bundle ID の確認
Xcodeで：
1. プロジェクト設定 → General → Bundle Identifier
2. `yokAppDev.quickMemoApp` と一致しているか確認

### 2. Xcodeでの設定

#### A. Capabilities の確認
1. プロジェクト設定 → Signing & Capabilities
2. 以下が有効になっているか確認：
   - ✅ In-App Purchase
   - ✅ App Groups (group.yokAppDev.quickMemoApp)

#### B. StoreKit Configuration
1. Product → Scheme → Edit Scheme
2. Run → Options
3. StoreKit Configuration: `StoreKitConfiguration.storekit` を選択
4. 一度「None」に設定して実行
5. その後、再度 `StoreKitConfiguration.storekit` を選択

### 3. Sandboxアカウントの設定

#### A. 新しいSandboxテスターを作成
1. App Store Connect → ユーザとアクセス → Sandbox
2. 「+」をクリックして新規作成
   - **実際のApple IDとは異なるメールアドレス**を使用
   - パスワードは強力なものに設定
   - 国/地域は「日本」に設定

#### B. デバイスでのサインイン
1. 設定 → App Store → 一番下の「サンドボックスアカウント」
2. 既存のアカウントからサインアウト
3. 新しいSandboxアカウントでサインイン

### 4. コンソールログの確認

アプリを実行してコンソールで以下を確認：

```
🔍 Loading products with IDs: [...]
❌ No network connection available
```
→ ネットワーク接続を確認

```
⚠️ No products found. Possible reasons:
   1. Product IDs don't match App Store Connect
   2. Products not approved in App Store Connect
   3. Bundle ID mismatch
   4. Agreements not accepted in App Store Connect
   5. StoreKit configuration issues
```
→ 上記の各項目を確認

### 5. トラブルシューティング手順

1. **クリーンビルド**
   ```
   Product → Clean Build Folder (Shift+Cmd+K)
   ```

2. **DerivedDataの削除**
   ```
   ~/Library/Developer/Xcode/DerivedData
   ```
   このフォルダ内のプロジェクトフォルダを削除

3. **Xcodeの再起動**

4. **デバイスの再起動**

5. **ネットワーク設定のリセット**
   - 設定 → 一般 → 転送またはiPhoneをリセット → リセット → ネットワーク設定をリセット

### 6. 実装済みの改善点

- **複数のProduct ID対応**: 異なるIDパターンに対応
- **ネットワーク接続チェック**: 接続状態を事前確認
- **詳細なエラーログ**: 問題の特定が容易
- **再試行ボタン**: 製品情報の再取得が可能
- **デバッグ情報表示**: Bundle IDと製品数を表示

### 7. それでも解決しない場合

#### A. StoreKit Testing in Xcodeを使用
1. File → New → File → StoreKit Configuration File
2. 製品を手動で追加
3. Schemeで新しいファイルを選択

#### B. TestFlightでテスト
1. アプリをTestFlightにアップロード
2. 内部テスターとして追加
3. TestFlight経由でテスト

#### C. デバッグモードを使用
設定画面で:
```swift
#if DEBUG
// Pro版として強制的に動作
PurchaseManager.shared.enableDebugMode()
PurchaseManager.shared.forceProVersion = true
#endif
```

### 8. チェックリスト

- [ ] App Store Connectで有料アプリ契約が有効
- [ ] Product IDが完全に一致
- [ ] Bundle IDが正しい
- [ ] In-App Purchase Capabilityが有効
- [ ] Sandboxアカウントが正しく設定されている
- [ ] ネットワーク接続が正常
- [ ] 製品のステータスが「提出準備完了」

### 9. よくある解決策

1. **最も一般的**: App Store Connectで有料アプリ契約を完了させる
2. **2番目に一般的**: Product IDの不一致を修正
3. **3番目**: Sandboxアカウントの再作成

## 連絡先

問題が解決しない場合は、以下の情報と共にApple Developer Supportに連絡：
- Bundle ID
- Product ID
- エラーメッセージ
- コンソールログ