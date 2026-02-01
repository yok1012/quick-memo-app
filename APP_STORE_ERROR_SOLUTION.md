# App Store Connect エラー解決ガイド

## エラー内容
```
errorCode = 4040004
errorMessage = "アプリが見つかりません"
AMSStatusCode = 404
```

このエラーは、App Store SandboxサーバーがアプリのBundle IDを認識できない場合に発生します。

## 根本原因

1. **App Store Connectでアプリが未作成**
2. **Bundle IDの不一致**
3. **In-App Purchase製品が未作成または未承認**

## 解決手順

### ステップ1: App Store Connectでアプリを作成

1. [App Store Connect](https://appstoreconnect.apple.com)にログイン
2. 「マイApp」→「+」→「新規App」
3. 以下の情報を入力：
   - **プラットフォーム**: iOS
   - **名前**: QuickMemo（または希望のアプリ名）
   - **プライマリ言語**: 日本語
   - **Bundle ID**: `yokAppDev.quickMemoApp`（Xcodeと完全一致）
   - **SKU**: 任意の一意識別子（例: QUICKMEMO001）

### ステップ2: In-App Purchase製品を作成

1. 作成したアプリを選択
2. 「App内課金」→「管理」→「+」
3. 製品タイプ：**非消耗型**
4. 以下の情報を入力：
   - **製品ID**: `yokAppDev.quickMemoApp.pro`
   - **参照名**: QuickMemo Pro
   - **価格**: ¥1,200（または希望の価格）
   - **表示名**: QuickMemo Pro
   - **説明**: すべての機能をアンロック

### ステップ3: 契約・税務情報の確認

1. App Store Connect →「契約/税金/銀行業務」
2. 「有料App」の契約状態を確認
3. ステータスが「アクティブ」でない場合：
   - 必要な情報をすべて入力
   - 税務フォームを記入
   - 銀行口座情報を設定

### ステップ4: Xcodeの設定確認

1. **Bundle IDの確認**
   ```
   プロジェクト設定 → General → Bundle Identifier
   yokAppDev.quickMemoApp（App Store Connectと完全一致）
   ```

2. **Capabilities確認**
   - In-App Purchase: ✅
   - App Groups: ✅ (group.yokAppDev.quickMemoApp)

3. **Team設定**
   - Signing & Capabilities → Team
   - 正しい開発者アカウントが選択されているか確認

### ステップ5: ローカルテストの代替方法

App Store Connect設定が完了するまでの間、以下の方法でテスト可能：

#### A. StoreKit Configuration File を使用

1. Xcodeで File → New → File
2. StoreKit Configuration File を選択
3. 製品を手動で追加
4. Scheme → Edit Scheme → Run → Options
5. StoreKit Configuration でファイルを選択

#### B. デバッグモードでPro版機能をテスト

設定画面でデバッグモードを有効化：
- 設定 → デバッグ設定 → Pro版として動作

## チェックリスト

### App Store Connect
- [ ] アプリが作成されている
- [ ] Bundle IDが正確に一致
- [ ] In-App Purchase製品が作成済み
- [ ] 製品のステータスが「提出準備完了」
- [ ] 契約・税務情報が完了（ステータス：アクティブ）

### Xcode
- [ ] Bundle IDがApp Store Connectと完全一致
- [ ] Teamが正しく設定されている
- [ ] In-App Purchase Capabilityが有効
- [ ] App Groupsが設定されている

### テスト環境
- [ ] Sandboxテストアカウントが作成済み
- [ ] デバイスでSandboxアカウントにサインイン済み

## よくある問題と解決策

### 問題1: 「アプリが見つかりません」エラー
**原因**: App Store Connectでアプリが未作成
**解決**: 上記ステップ1を実行

### 問題2: Product IDが見つからない
**原因**: In-App Purchase製品が未作成
**解決**: 上記ステップ2を実行

### 問題3: 契約エラー
**原因**: 有料App契約が未完了
**解決**: 上記ステップ3を実行

## 推奨される次のアクション

1. **今すぐ実行**:
   - App Store Connectでアプリを作成
   - Bundle IDを確認・修正

2. **その後**:
   - In-App Purchase製品を作成
   - Sandboxテストを実施

3. **デバッグ中**:
   - デバッグモードでPro機能をテスト
   - StoreKit Configuration Fileを使用

## サポート連絡先

問題が解決しない場合：
- Apple Developer Support
- 必要情報：Bundle ID、エラーログ、App Store Connect スクリーンショット