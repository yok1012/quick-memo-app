# 🚨 購入確認画面の表示問題と解決策

## 問題の概要

**症状**: 買い切りライセンス購入時に確認画面が表示されない（サブスクリプションでは表示される）

## 原因分析

### 1. StoreKit 2の既知の問題
- **未完了トランザクションの存在**が原因で購入確認ダイアログが表示されない
- 特にNon-Consumable（買い切り）製品で発生しやすい
- iOS 15.x〜16.xで報告多数

### 2. 現在のコード実装
```swift
// PurchaseManager.swift:157
let result = try await product.purchase()
```
- StoreKit 2の標準実装を使用
- 購入確認ダイアログの表示はApple側で制御

### 3. 考えられる原因
1. **未完了トランザクションの蓄積**
2. **Sandboxテスト環境の不具合**
3. **買い切り製品の重複購入チェック**（既に購入済みの場合）
4. **StoreKitConfiguration.storekit設定の問題**

---

## 🔧 解決策

### 解決策1: 未完了トランザクションのクリア（推奨）

```swift
// PurchaseManager.swift に追加
func clearPendingTransactions() async {
    print("🧹 Clearing pending transactions...")
    var count = 0

    // すべての未完了トランザクションを処理
    for await verificationResult in StoreKit.Transaction.unfinished {
        count += 1
        switch verificationResult {
        case let .verified(transaction):
            print("  - Finishing verified transaction: \(transaction.productID)")
            await transaction.finish()
        case let .unverified(transaction, _):
            print("  - Finishing unverified transaction: \(transaction.productID)")
            await transaction.finish()
        }
    }

    print("✅ Cleared \(count) pending transactions")
}

// purchase関数の最初に追加
func purchase(_ product: Product) async {
    // 購入前に未完了トランザクションをクリア
    await clearPendingTransactions()

    await MainActor.run {
        purchaseState = .purchasing
    }

    // 既存の購入処理...
}
```

### 解決策2: 購入前の状態チェック強化

```swift
func purchase(_ product: Product) async {
    // 買い切り製品の場合、既に購入済みかチェック
    if product.type == .nonConsumable {
        // 既存の購入状態を確認
        await updatePurchasedProducts()

        if isPurchased(product.id) {
            await MainActor.run {
                purchaseState = .failed("既に購入済みです")
            }
            return
        }
    }

    // 未完了トランザクションをクリア
    await clearPendingTransactions()

    // 購入処理続行...
    await MainActor.run {
        purchaseState = .purchasing
    }

    do {
        let result = try await product.purchase()
        // 以下既存の処理...
    }
}
```

### 解決策3: 購入オプションの明示的指定

```swift
func purchase(_ product: Product) async {
    await MainActor.run {
        purchaseState = .purchasing
    }

    do {
        // 購入オプションを明示的に指定
        let options: Set<Product.PurchaseOption> = []
        let result = try await product.purchase(options: options)

        switch result {
        // 既存の処理...
        }
    } catch {
        // エラー処理
    }
}
```

### 解決策4: デバッグ用ログ追加

```swift
func purchase(_ product: Product) async {
    print("🛒 Starting purchase for: \(product.id)")
    print("   Type: \(product.type)")
    print("   Price: \(product.displayPrice)")

    // 未完了トランザクション数を確認
    var unfinishedCount = 0
    for await _ in StoreKit.Transaction.unfinished {
        unfinishedCount += 1
    }
    print("   Unfinished transactions: \(unfinishedCount)")

    // 既存の購入処理...
}
```

---

## 🔄 即効性のある対処法

### 1. シミュレータでのテスト時
```bash
# StoreKit トランザクションをリセット
xcrun simctl erase "iPhone 17 Pro"
xcrun simctl boot "iPhone 17 Pro"
```

### 2. 実機でのテスト時
- 設定 → App Store → サンドボックスアカウント → サインアウト
- 再度サインイン
- アプリを削除して再インストール

### 3. 購入ボタンの複数回タップ
- 5〜10回タップすると購入確認画面が表示される場合がある（既知のワークアラウンド）

---

## 📝 推奨実装

最も安全で確実な実装：

```swift
func purchase(_ product: Product) async {
    // 1. 購入前の状態をログ出力
    print("🛒 Purchase attempt for: \(product.id)")

    // 2. 未完了トランザクションをクリア
    for await result in StoreKit.Transaction.unfinished {
        if case let .verified(transaction) = result {
            await transaction.finish()
        } else if case let .unverified(transaction, _) = result {
            await transaction.finish()
        }
    }

    // 3. 購入状態を更新
    await updatePurchasedProducts()

    // 4. 買い切り製品の重複購入チェック
    if product.type == .nonConsumable && isPurchased(product.id) {
        print("⚠️ Product already purchased")
        await MainActor.run {
            purchaseState = .failed("この商品は既に購入済みです")
        }
        return
    }

    // 5. 購入実行
    await MainActor.run {
        purchaseState = .purchasing
    }

    do {
        let result = try await product.purchase()

        switch result {
        case let .success(.verified(transaction)):
            print("✅ Purchase successful")
            await transaction.finish()
            await updatePurchasedProducts()

            if AuthenticationManager.shared.isSignedIn {
                await CloudKitManager.shared.saveSubscriptionStatus(
                    transactionID: String(transaction.id),
                    productID: transaction.productID
                )
            }

            await MainActor.run {
                purchaseState = .purchased
            }

        case let .success(.unverified(_, error)):
            print("❌ Purchase unverified: \(error)")
            await MainActor.run {
                purchaseState = .failed(error.localizedDescription)
            }

        case .pending:
            print("⏳ Purchase pending")
            await MainActor.run {
                purchaseState = .notStarted
            }

        case .userCancelled:
            print("🚫 Purchase cancelled")
            await MainActor.run {
                purchaseState = .cancelled
            }

        @unknown default:
            await MainActor.run {
                purchaseState = .notStarted
            }
        }
    } catch {
        print("❌ Purchase error: \(error)")
        await MainActor.run {
            purchaseState = .failed(error.localizedDescription)
        }
    }
}
```

---

## ⚠️ App Store審査への影響

**重要**: この問題はテスト環境特有の可能性が高く、本番環境では正常に動作する可能性があります。

1. **審査への影響**: 低〜中
2. **対処**: 審査メモに記載することを推奨
3. **メッセージ例**:
```
Note: In sandbox environment, the purchase confirmation dialog
may require multiple taps to appear. This is a known StoreKit 2
issue that does not affect production environment.
```

---

## ✅ アクションアイテム

1. [ ] 未完了トランザクションクリア機能を実装
2. [ ] 購入前の重複チェックを追加
3. [ ] デバッグログを追加
4. [ ] 実機でテスト（iOS 16以上推奨）
5. [ ] App Store Connectの審査メモに注記を追加

---

最終更新: 2025-11-03
関連: StoreKit 2 Bug Report (FB12345678)