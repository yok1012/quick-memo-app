# 📸 App Review用スクリーンショット作成ガイド

## 🎯 必要なスクリーンショット

### 買い切りライセンス用
- **Product ID**: `yokAppDev.quickMemoApp.pro`
- **必要な画像**: 購入画面（価格表示あり）

### 月額サブスクリプション用
- **Product ID**: `com.yokAppDev.quickMemoApp.pro.month`
- **必要な画像**: 購入画面（価格表示あり）

---

## 📱 スクリーンショット撮影手順

### Step 1: シミュレータ準備
```bash
# シミュレータをリセット（クリーンな状態から始める）
xcrun simctl shutdown all
xcrun simctl erase all

# iPhone 17 Proを起動
xcrun simctl boot "iPhone 17 Pro"
```

### Step 2: アプリをビルド＆インストール
```bash
# Releaseモードでビルド（StoreKit製品が表示される）
xcodebuild -project quickMemoApp.xcodeproj \
  -scheme quickMemoApp \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# アプリをインストール
xcrun simctl install "iPhone 17 Pro" \
  /Users/kiichiyokokawa/Library/Developer/Xcode/DerivedData/quickMemoApp-*/Build/Products/Release-iphonesimulator/quickMemoApp.app

# アプリを起動
xcrun simctl launch "iPhone 17 Pro" yokAppDev.quickMemoApp
```

### Step 3: 購入画面へ遷移
1. アプリが起動したら「設定」タブをタップ
2. 「QuickMemo Proにアップグレード」をタップ
3. 購入画面が表示されるまで待機

### Step 4: スクリーンショット撮影

#### シミュレータでの撮影方法
- **方法1**: Command + S（シミュレータメニュー → Device → Screenshot）
- **方法2**: xcrun simctl io "iPhone 17 Pro" screenshot ~/Desktop/purchase_screen.png

#### 理想的な構図
```
┌─────────────────────────┐
│    QuickMemo Pro        │
│      ⭐️⭐️⭐️⭐️⭐️       │
│                         │
│  [Pro機能の説明]        │
│  ✓ 無制限メモ          │
│  ✓ 無制限カテゴリ      │
│  ✓ iCloud同期          │
│                         │
│ ┌─────────────────┐   │
│ │ 月額サブスク      │   │
│ │   ¥200/月        │   │
│ └─────────────────┘   │
│                         │
│ ┌─────────────────┐   │
│ │ 買い切りライセンス│   │
│ │     ¥500         │   │
│ └─────────────────┘   │
│                         │
│ [購入を復元]            │
└─────────────────────────┘
```

---

## 🎨 スクリーンショット要件

### 技術仕様
- **最小サイズ**: 640 × 920 ピクセル
- **推奨サイズ**: 1242 × 2208 ピクセル（iPhone 6.5インチ）
- **形式**: JPEG または PNG
- **向き**: 縦向き

### 内容チェックリスト
- ✅ 製品名が表示されている
- ✅ 価格が明確に見える
- ✅ 購入ボタンがアクティブ状態
- ✅ Pro機能の説明が見える
- ✅ 両方の購入オプションが表示されている

### やってはいけないこと
- ❌ 価格を隠す
- ❌ テスト環境の表示を含める
- ❌ デバッグ情報を表示
- ❌ 個人情報を含める

---

## 📤 App Store Connectへのアップロード

### 1. In-App Purchase製品ページへ移動
1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. マイApp → quickMemoApp
3. 機能 → アプリ内購入
4. 対象の製品を選択

### 2. スクリーンショット追加
1. 「審査に関する情報」セクションまでスクロール
2. 「スクリーンショット」の「ファイルを選択」をクリック
3. 撮影した画像を選択
4. 「保存」をクリック

### 3. 両方の製品に追加
- `yokAppDev.quickMemoApp.pro`（買い切り）
- `com.yokAppDev.quickMemoApp.pro.month`（月額）

両方に同じスクリーンショットを使用可能（両製品が表示されているため）

---

## 🔍 トラブルシューティング

### 製品が表示されない場合
```bash
# StoreKit設定を確認
cat StoreKitConfiguration.storekit

# ログを確認しながら再起動
xcrun simctl launch --console "iPhone 17 Pro" yokAppDev.quickMemoApp
```

### 価格が表示されない場合
1. ネットワーク接続を確認
2. シミュレータを再起動
3. App Store Connectで製品ステータスを確認

### スクリーンショットがアップロードできない場合
- ファイルサイズが大きすぎないか確認（10MB以下推奨）
- 画像形式がJPEGまたはPNGか確認
- 最小解像度（640×920）を満たしているか確認

---

## ✅ 最終チェックリスト

- [ ] シミュレータで購入画面を表示
- [ ] 両方の製品と価格が見える
- [ ] スクリーンショットを撮影
- [ ] 画像の要件を確認（サイズ、形式）
- [ ] App Store Connectにアップロード
- [ ] 両方のIAP製品に追加
- [ ] 「保存」をクリック
- [ ] ステータスが「Ready to Submit」を確認

---

最終更新: 2025-11-03
対象バージョン: Version 1.0, Build 2