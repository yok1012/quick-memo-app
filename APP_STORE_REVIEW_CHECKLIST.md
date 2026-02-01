# App Store審査対応チェックリスト

## 🚨 リジェクト理由と対応状況

### Guideline 3.1.1違反の内容
- **問題**: 最初のアプリ内課金は、新しいアプリバージョンと共に提出する必要があります
- **原因**: In-App Purchaseがアプリ本体と一緒に提出されていない
- **Appleメッセージ**: 「印がついている項目を修正してください」

## ✅ 緊急対応項目

### 1. App Store Connect - In-App Purchase設定

#### 買い切りライセンス (Non-Consumable)
- **Product ID**: `yokAppDev.quickMemoApp.pro`
- **価格**: $4.99 (¥500相当)
- **表示名**: 買い切りライセンス / One-time Purchase

**必須項目のステータス**:
- [ ] **App Reviewスクリーンショット** ← ⚠️ **未添付が原因でリジェクト**
- [x] ローカライゼーション（日本語・英語・中国語）
- [x] 価格設定
- [x] 審査メモ

#### 月額サブスクリプション (Auto-Renewable)
- **Product ID**: `com.yokAppDev.quickMemoApp.pro.month`
- **価格**: $1.99/月 (¥200相当)
- **表示名**: QuickMemo Pro月額

**必須項目のステータス**:
- [ ] **App Reviewスクリーンショット** ← ⚠️ **未添付が原因でリジェクト**
- [x] ローカライゼーション（日本語・英語・中国語）
- [x] 価格設定
- [x] サブスクリプショングループ設定
- [x] 審査メモ

## 📸 App Reviewスクリーンショットの要件

### 必要な画像
1. **購入画面のスクリーンショット**
   - サイズ: 最小 640×920ピクセル（推奨: 1242×2208 - iPhone 6.5インチ）
   - 形式: JPEGまたはPNG
   - 内容:
     - 購入ボタンが表示されている状態
     - 価格が明確に見える
     - 「買い切りライセンス」と「月額サブスクリプション」の両方が見える

### スクリーンショットの作成方法
```bash
# 1. シミュレータで購入画面を開く
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl launch "iPhone 17 Pro" yokAppDev.quickMemoApp

# 2. 購入画面まで遷移
# - 設定タブ → QuickMemo Proにアップグレード

# 3. スクリーンショットを撮影
# - Command + S でシミュレータのスクリーンショットを保存
```

## 🔄 再提出手順

### Step 1: App Store Connectでの修正
1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. **マイApp** → **quickMemoApp** → **機能** → **アプリ内購入**
3. 各In-App Purchase製品を開く:
   - `yokAppDev.quickMemoApp.pro` (買い切り)
   - `com.yokAppDev.quickMemoApp.pro.month` (月額)
4. **審査に関する情報** セクション
5. **スクリーンショット** → **ファイルを選択**
6. 購入画面のスクリーンショットをアップロード
7. **保存**
8. ステータスが「Ready to Submit」になることを確認

### Step 2: 新しいビルドの作成とアップロード
```bash
# アーカイブ作成
xcodebuild -project quickMemoApp.xcodeproj \
  -scheme quickMemoApp \
  -configuration Release \
  -archivePath ./build/quickMemoApp.xcarchive \
  archive

# App Store Connectへアップロード
# Xcodeから: Product → Archive → Distribute App → App Store Connect
```

### Step 3: バージョン設定でIAPを関連付け
1. App Store Connect → **App Store** タブ
2. **バージョン 1.0** を選択
3. ページ下部の **アプリ内課金とサブスクリプション** セクション
4. 両方のIAPにチェック:
   - ☑️ QuickMemo Pro（買い切り）
   - ☑️ QuickMemo Pro月額
5. **審査に提出** ボタンをクリック

## 📝 Appleへの返信メッセージ例

### Resolution Centerへの返信（英語）
```
Hello,

Thank you for your review. We have addressed the issues as follows:

1. Added the required App Review screenshots for both In-App Purchase products:
   - Non-Consumable: "QuickMemo Pro (One-time Purchase)"
   - Auto-Renewable Subscription: "QuickMemo Pro Monthly"

2. Uploaded a new binary (Version 1.0, Build 3) with both IAPs properly associated

3. Both in-app purchases are now being submitted together with the app binary for review

The screenshots clearly show:
- Purchase buttons with prices
- Product descriptions in Japanese, English, and Chinese
- Both purchase options (one-time and subscription)

We have ensured all required metadata is complete and the products are ready for review.

Thank you for your guidance.

Best regards,
Kiichi Yokokawa
```

## ⚠️ 注意事項

### コード側の確認済み項目
- ✅ Product IDが完全一致 (PurchaseManager.swift:11-12)
- ✅ 「買い切りライセンス」の表示実装済み (PurchaseView.swift:177)
- ✅ 復元ボタンが買い切りの直下に配置済み (PurchaseView.swift:98-123)
- ✅ StoreKit 1のプロモーション購入対応済み (PurchaseManager.swift:396-455)

### App Store Connect側で必要な作業
- ❌ **App Reviewスクリーンショットの追加** ← 最優先
- ⚠️ 新しいビルドのアップロード
- ⚠️ IAPとビルドの関連付け
- ⚠️ 一緒に審査提出

## 🎯 成功の鍵

1. **スクリーンショットは必須**: これが無いと100%リジェクトされます
2. **IAPとアプリを一緒に提出**: 個別提出はNG
3. **Product IDの完全一致**: 1文字でも違うと動作しません

## 📅 推定タイムライン

1. スクリーンショット追加: 15分
2. ビルドアップロード: 30分
3. 再提出: 5分
4. 審査待ち: 24-48時間

---

最終更新: 2025-11-03
ステータス: App Reviewスクリーンショット未添付によりリジェクト中