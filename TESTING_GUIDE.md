# 🧪 購入機能テストガイド

## 📱 テスト環境
- Xcode 16.2
- iOS Simulator (iPhone 17 Pro)
- Debug Configuration

## 🔄 購入テストの手順

### Step 1: 購入状態のリセット
```
1. アプリを起動
2. 設定タブを開く
3. 一番下までスクロール
4. 「デバッグツール」セクション
5. 「購入状態をリセット」をタップ
```

### Step 2: 購入画面へ移動
```
1. 設定タブ内
2. 「QuickMemo Proにアップグレード」をタップ
3. 購入画面が表示される
```

### Step 3: 購入を実行
```
1. 月額サブスクリプション（青ボタン）または
   買い切りライセンス（緑ボタン）をタップ
2. Face ID/Touch ID認証画面が表示される ✅
3. 認証を完了
```

## 🔍 コンソールログの確認

### Xcodeでログを確認
```bash
# Xcodeのコンソールで以下のようなログが表示される
🛒 Starting purchase for: yokAppDev.quickMemoApp.pro
   Type: Product.ProductType.nonConsumable
   Price: ¥500
🔍 Checking for unfinished transactions...
🔄 Calling product.purchase()...
✅ Purchase successful: yokAppDev.quickMemoApp.pro
```

### macOS Consoleアプリで確認
```bash
# Consoleアプリを開く
open -a Console

# フィルター: "quickMemo"
# プロセス: "quickMemoApp"
```

## 🐛 トラブルシューティング

### 購入画面が表示されない
```bash
# シミュレータをリセット
xcrun simctl erase "iPhone 17 Pro"
xcrun simctl boot "iPhone 17 Pro"

# アプリを再インストール
xcrun simctl install "iPhone 17 Pro" [app path]
xcrun simctl launch "iPhone 17 Pro" yokAppDev.quickMemoApp
```

### Face ID認証画面が表示されない
```swift
// デバッグツールで購入状態をリセット
// Settings > Debug Tools > Reset Purchase State
```

### 「既に購入済み」エラー
```
1. デバッグツールで購入状態をリセット
2. アプリを削除して再インストール
3. シミュレータをリセット
```

## 📊 期待される動作

| アクション | 期待される結果 | 確認方法 |
|-----------|--------------|---------|
| 購入ボタンタップ | Face ID画面表示 | 視覚的に確認 |
| 認証完了 | 購入成功メッセージ | アラート表示 |
| 購入後の状態 | Pro版として認識 | 設定画面に反映 |
| 復元ボタン | 購入履歴を復元 | コンソールログ |

## 🎯 重要な確認ポイント

### ✅ 正常動作の確認
- [ ] Face ID/Touch ID認証画面が表示される
- [ ] 購入成功後、Pro版として認識される
- [ ] 復元機能が正常に動作する
- [ ] デバッグリセット後、再購入が可能

### ⚠️ エッジケース
- [ ] ネットワーク切断時の動作
- [ ] 購入キャンセル時の処理
- [ ] 重複購入の処理（StoreKitが自動処理）

## 📝 デバッグコマンド集

### シミュレータ操作
```bash
# 起動中のシミュレータ一覧
xcrun simctl list devices | grep Booted

# ログをリアルタイムで確認
xcrun simctl spawn booted log stream --predicate 'processImagePath ENDSWITH "quickMemoApp"'

# スクリーンショット撮影
xcrun simctl io "iPhone 17 Pro" screenshot ~/Desktop/test.png
```

### StoreKit関連
```bash
# StoreKit Configuration確認
cat StoreKitConfiguration.storekit | grep productID

# 購入製品ID確認
grep -r "yokAppDev.quickMemoApp.pro" .
```

## 🚀 本番環境への移行

### リリース前チェックリスト
1. **デバッグコードの確認**
   ```swift
   #if DEBUG
   // デバッグコードがここに
   #endif
   ```

2. **Release Configurationでビルド**
   ```bash
   xcodebuild -configuration Release
   ```

3. **App Store Connect設定**
   - In-App Purchase製品の設定
   - 審査用スクリーンショット追加
   - 審査メモの記載

## 📞 サポート

問題が解決しない場合：
1. コンソールログを確認
2. `PURCHASE_FIX_SOLUTION.md`を参照
3. `PURCHASE_CONFIRMATION_ISSUE.md`を確認

---

最終更新: 2025-11-03
テストバージョン: 1.0 (Build 2)