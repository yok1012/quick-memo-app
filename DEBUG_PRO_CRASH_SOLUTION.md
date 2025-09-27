# デバッグPro版クラッシュの解決策

## 問題の根本原因
1. **循環参照の問題**: NotificationManagerの初期化時にPurchaseManager.sharedを参照していたため、初期化の順序によってクラッシュが発生
2. **スレッドの競合**: NotificationManagerがMainActorで動作していなかったため、UIスレッドとバックグラウンドスレッドで競合状態が発生
3. **初期化タイミング**: Pro版状態の変更通知が初期化完了前に発生し、不完全な状態でアクセスが行われていた

## 実装した解決策

### 1. NotificationManagerを@MainActorに変更
```swift
@MainActor
class NotificationManager: NSObject, ObservableObject {
```
これにより、すべてのプロパティアクセスがメインスレッドで行われるように保証

### 2. 初期化時の循環参照を回避
```swift
override init() {
    super.init()
    loadSettings()
    isInitializing = false
    
    // 通知の登録を遅延実行
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.setupPurchaseStatusObserver()
    }
}
```
PurchaseManagerへのアクセスを遅延させることで、初期化の競合を回避

### 3. スレッドセーフな通知スケジューリング
```swift
func scheduleNotifications() {
    Task { @MainActor in
        // Pro版チェックをメインスレッドで実行
        let isProVersion = PurchaseManager.shared.isProVersion
        // 必要な値をキャプチャ
        
        // バックグラウンドで通知をスケジュール
        DispatchQueue.global(qos: .background).async {
            self.scheduleNotificationsInBackground(...)
        }
    }
}
```
メインスレッドで必要な値を取得してから、バックグラウンドで処理を実行

### 4. Pro版状態変更の監視を改善
```swift
private func setupPurchaseStatusObserver() {
    purchaseStatusObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("PurchaseStatusChanged"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            // Pro版状態の変更を安全に処理
        }
    }
}
```

### 5. デバッグ設定での安全な切り替え
- NotificationManagerを@StateObjectとして保持
- Pro版切り替え時にログを出力して状態を追跡
- Pro版無効化時に通知設定も自動的に無効化

## テスト手順
1. アプリを完全に終了
2. Xcodeでクリーンビルド（Command + Shift + K）
3. アプリを起動
4. デバッグ設定を開く
5. デバッグモードを有効化
6. Pro版スイッチをオン/オフ切り替え
7. 設定画面で通知設定を確認

## 今後の改善案
1. 依存性注入パターンの導入で、より明確な初期化順序を実現
2. Combine frameworkを使用したリアクティブな状態管理
3. アクターモデルを使用したより安全な並行処理