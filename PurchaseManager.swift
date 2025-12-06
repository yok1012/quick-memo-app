import StoreKit
import SwiftUI

@MainActor
class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()
    
    // Product identifiers - App Store Connect で設定した実際のProduct IDと一致させる
    // 月額サブスクリプション（Auto-Renewable Subscription）
    private let monthlySubscriptionID = "com.yokAppDev.quickMemoApp.pro.month"
    // 永久ライセンス（Non-Consumable）
    private let lifetimeID = "yokAppDev.quickMemoApp.pro"

    // すべての商品ID
    private let allProductIDs: Set<String> = [
        "com.yokAppDev.quickMemoApp.pro.month",
        "yokAppDev.quickMemoApp.pro"
    ]
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isProVersion: Bool = false {
        didSet {
            if oldValue != isProVersion {
                NotificationCenter.default.post(
                    name: NSNotification.Name("PurchaseStatusChanged"),
                    object: nil
                )
            }
        }
    }
    @Published var purchaseState: PurchaseState = .notStarted
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // MARK: - Debug Properties

    #if DEBUG
    // デバッグ用：購入状態を強制的にリセット
    func debugResetPurchaseState() async {
        print("🔧 DEBUG: Force resetting purchase state")

        // 購入済み製品IDをクリア
        await MainActor.run {
            self.purchasedProductIDs.removeAll()
            self.isProVersion = false
            self.purchaseState = .notStarted
        }

        // UserDefaultsをクリア
        if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
            sharedDefaults.removeObject(forKey: "isPurchased")
            sharedDefaults.synchronize()
        }

        print("✅ DEBUG: Purchase state reset complete")
    }

    // デバッグ用：購入状態を強制的に更新（StoreKitを無視）
    private var debugSkipStoreKit = false

    func debugSetSkipStoreKit(_ skip: Bool) {
        debugSkipStoreKit = skip
        print("🔧 DEBUG: Skip StoreKit = \(skip)")
    }
    #endif

    // MARK: - Debug Properties (Removed for production)
    
    enum PurchaseState: Equatable {
        case notStarted
        case purchasing
        case purchased
        case failed(String)
        case cancelled

        static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.purchasing, .purchasing),
                 (.purchased, .purchased),
                 (.cancelled, .cancelled):
                return true
            case let (.failed(lhsError), .failed(rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    // 購入状態の読み込みが完了したかどうか
    @Published var isLoadingComplete: Bool = false

    override init() {
        super.init()

        // StoreKit 1のオブザーバーを登録（プロモーション購入対応）
        SKPaymentQueue.default().add(self)

        // Start transaction update listener for StoreKit 2
        updateListenerTask = listenForTransactions()

        // 未完了のトランザクションを起動時に処理
        Task {
            await processUnfinishedTransactions()
        }

        // Load products on initialization
        Task {
            await loadProducts()
            await updatePurchasedProducts()

            // CloudKitから購入状態を同期（iCloudが利用可能な場合）
            // Note: isSignedInチェックを削除 - iCloudアカウントがあれば同期可能
            if await CloudKitManager.shared.isiCloudAvailable() {
                await CloudKitManager.shared.syncSubscriptionStatus()
            }

            // 読み込み完了をマーク
            await MainActor.run {
                self.isLoadingComplete = true
                print("✅ PurchaseManager: Loading complete, isProVersion = \(self.isProVersion)")
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {

        do {

            // ネットワーク接続を確認
            let isConnected = await checkNetworkConnection()
            if !isConnected {
                return
            }

            // すべての可能なProduct IDで試す
            let products = try await Product.products(for: allProductIDs)


            if products.isEmpty {
            }

            await MainActor.run {
                self.products = products
            }
        } catch let error as StoreKitError {
            handleStoreKitError(error)
        } catch {

            // エラーメッセージから404を検出
            if error.localizedDescription.contains("404") ||
               error.localizedDescription.contains("アプリが見つかりません") {
            }
        }
    }

    private func checkNetworkConnection() async -> Bool {
        // ネットワーク確認をスキップ（StoreKitが自動的に処理）
        // ネットワークチェックが原因で製品読み込みが失敗する可能性があるため
        return true
    }

    private func handleStoreKitError(_ error: StoreKitError) {
        switch error {
        case .networkError(let urlError):
            break
        case .systemError(let nsError):
            break
        case .userCancelled:
            break
        case .notAvailableInStorefront:
            break
        case .notEntitled:
            break
        case .unknown:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Purchase Management

    func purchase(_ product: Product) async {
        // 購入前のログ出力
        print("🛒 Starting purchase for: \(product.id)")
        print("   Type: \(product.type)")
        print("   Price: \(product.displayPrice)")

        // 未完了トランザクションの確認（finish()はしない）
        print("🔍 Checking for unfinished transactions...")
        var unfinishedCount = 0
        var unfinishedProducts: [String] = []

        for await verificationResult in StoreKit.Transaction.unfinished {
            unfinishedCount += 1
            switch verificationResult {
            case let .verified(transaction):
                unfinishedProducts.append(transaction.productID)
                print("   - Found unfinished verified transaction: \(transaction.productID)")
                // 注意: ここでfinish()すると購入プロセスが正常に動作しない可能性がある
                // StoreKit 2は自動的に処理するので、明示的なfinish()は購入成功後のみ行う
            case let .unverified(transaction, _):
                print("   - Found unfinished unverified transaction: \(transaction.productID)")
                // 未検証のトランザクションも同様に、ここではfinish()しない
            }
        }

        if unfinishedCount > 0 {
            print("⚠️ Found \(unfinishedCount) unfinished transactions: \(unfinishedProducts)")
            print("   These will be handled by StoreKit automatically")
        }

        // 購入状態を更新（デバッグ用）
        await updatePurchasedProducts()

        // 買い切り製品の重複購入チェック
        // 注意: StoreKit 2は自動的に重複購入を処理するため、
        // 明示的なチェックは不要。むしろFace ID認証画面が表示されない原因になる。
        // StoreKitが購入済みの場合は適切なエラーを返してくれる。
        /*
        if product.type == .nonConsumable && isPurchased(product.id) {
            print("⚠️ Product already purchased: \(product.id)")
            await MainActor.run {
                purchaseState = .failed("この商品は既に購入済みです")
            }
            return
        }
        */

        // 現在の購入状態をログ出力
        if isPurchased(product.id) {
            print("ℹ️ Note: Product may already be purchased, but proceeding to let StoreKit handle it")
        }

        await MainActor.run {
            purchaseState = .purchasing
        }

        do {
            print("🔄 Calling product.purchase()...")
            let result = try await product.purchase()
            
            switch result {
            case let .success(.verified(transaction)):
                // A successful purchase
                print("✅ Purchase successful: \(transaction.productID)")
                await transaction.finish()
                await updatePurchasedProducts()

                // CloudKitに購入情報を保存（ユーザーがサインインしている場合）
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
                // Successful purchase but transaction/receipt can't be verified
                print("❌ Purchase unverified: \(error)")
                await MainActor.run {
                    purchaseState = .failed(error.localizedDescription)
                }

            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or approval from Ask to Buy
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
                print("❓ Unknown purchase result")
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
    
    func restorePurchases() async {
        await MainActor.run {
            purchaseState = .purchasing
        }

        do {
            // App Store と同期して購入履歴を復元
            try await AppStore.sync()

            // 購入済み商品を更新
            await updatePurchasedProducts()

            // CloudKitからも購入状態を確認（サインインしている場合）
            if AuthenticationManager.shared.isSignedIn {
                let (isPro, _) = await CloudKitManager.shared.fetchSubscriptionStatus()
                if isPro {
                    await MainActor.run {
                        self.isProVersion = true
                    }
                }
            }

            // 復元結果をチェック
            let hasProVersion = await MainActor.run { self.isProVersion }

            await MainActor.run {
                if hasProVersion {
                    purchaseState = .purchased
                } else {
                    purchaseState = .failed("購入履歴が見つかりませんでした")
                }
            }
        } catch {
            await MainActor.run {
                purchaseState = .failed("復元に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Transaction Handling
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await verificationResult in StoreKit.Transaction.updates {
                await self.handle(transactionVerification: verificationResult)
            }
        }
    }
    
    private func handle(transactionVerification result: VerificationResult<StoreKit.Transaction>) {
        switch result {
        case .verified(let transaction):
            // Handle verified transaction
            Task {
                await transaction.finish()
                await updatePurchasedProducts()
            }
        case .unverified(_, let error):
            // Handle unverified transaction
            break
        }
    }
    
    private func updatePurchasedProducts() async {
        #if DEBUG
        // デバッグモード：StoreKitをスキップ
        if debugSkipStoreKit {
            print("🔧 DEBUG: Skipping StoreKit update (debugSkipStoreKit = true)")
            return
        }
        #endif

        var purchasedProductIDs: Set<String> = []
        var transactionCount = 0

        // すべての現在の権利を確認（サブスクリプションと非消耗型の両方）
        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            transactionCount += 1
            switch verificationResult {
            case let .verified(transaction):
                // 取り消されていない有効な購入を確認
                if transaction.revocationDate == nil {
                    purchasedProductIDs.insert(transaction.productID)

                    // サブスクリプションの場合、有効期限を確認
                    if transaction.productType == .autoRenewable {
                        if let expirationDate = transaction.expirationDate,
                           expirationDate > Date() {
                            // 有効なサブスクリプション
                            purchasedProductIDs.insert(transaction.productID)
                        }
                    } else {
                        // 非消耗型（永久ライセンス）
                        purchasedProductIDs.insert(transaction.productID)
                    }
                }

            case let .unverified(transaction, error):
                break
            }
        }


        await MainActor.run {
            self.purchasedProductIDs = purchasedProductIDs
            // いずれかのPro版Product IDが購入済みかチェック
            self.isProVersion = !purchasedProductIDs.isDisjoint(with: allProductIDs)


            // App Groupに保存（Watch/Widget用）
            if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
                sharedDefaults.set(self.isProVersion, forKey: "isPurchased")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }
    
    func getProduct(for productID: String) -> Product? {
        return products.first { $0.id == productID }
    }
    
    // MARK: - Feature Access Control
    
    func canCreateMoreMemos(currentCount: Int) -> Bool {
        if isProVersion {
            return true // Unlimited for pro users
        }
        return currentCount < 100 // Free users limited to 100 memos
    }
    
    func canCreateMoreCategories(currentCount: Int) -> Bool {
        if isProVersion {
            return true // Unlimited for pro users
        }
        return currentCount < 5 // Free users limited to 5 categories
    }
    
    func canUseAdvancedFeatures() -> Bool {
        return isProVersion
    }

    func canCustomizeWidget() -> Bool {
        return isProVersion
    }

    func canUseUnlimitedTags() -> Bool {
        if isProVersion {
            return true // Unlimited for pro users
        }
        return false // Free users limited to 15 tags per memo
    }

    func canUseiCloudSync() -> Bool {
        return isProVersion // iCloud sync is Pro only
    }

    func getMaxTagsPerMemo() -> Int {
        return isProVersion ? Int.max : 15
    }

    /// 購入状態の読み込みが完了するまで待機する
    /// アプリ起動時のiCloud復元判定前に呼び出す
    func waitForLoadingComplete() async {
        // 既に完了していればすぐ返す
        if isLoadingComplete {
            print("✅ PurchaseManager: Already loaded")
            return
        }

        print("⏳ PurchaseManager: Waiting for loading to complete...")

        // 最大5秒待機（通常はもっと早く完了する）
        let maxWait: TimeInterval = 5.0
        let startTime = Date()

        while !isLoadingComplete {
            // タイムアウトチェック
            if Date().timeIntervalSince(startTime) > maxWait {
                print("⚠️ PurchaseManager: Loading timeout, proceeding anyway")
                break
            }

            // 100msごとにチェック
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        print("✅ PurchaseManager: Wait complete, isProVersion = \(isProVersion)")
    }

    // MARK: - Unfinished Transactions

    private func processUnfinishedTransactions() async {
        // StoreKit 2の未完了トランザクションを処理
        for await verificationResult in StoreKit.Transaction.unfinished {
            switch verificationResult {
            case let .verified(transaction):
                // 検証済みのトランザクションを処理
                await handleVerifiedTransaction(transaction)
            case let .unverified(transaction, error):
                // 未検証のトランザクションは完了させる
                await transaction.finish()
            }
        }
    }

    private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        // トランザクションを完了
        await transaction.finish()

        // 購入状態を更新
        await updatePurchasedProducts()

        // CloudKitに保存（サインイン時）
        if AuthenticationManager.shared.isSignedIn {
            await CloudKitManager.shared.saveSubscriptionStatus(
                transactionID: String(transaction.id),
                productID: transaction.productID
            )
        }
    }
}

// MARK: - StoreKit 1 Delegate (for Promoted Purchase)

extension PurchaseManager: SKPaymentTransactionObserver {

    // プロモーション購入の受け口
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        // プロモーション購入を受け入れる
        // true を返すことで、購入フローが自動的に開始される
        return true
    }

    // トランザクションの更新を処理
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // 購入成功
                SKPaymentQueue.default().finishTransaction(transaction)
                // StoreKit 2側で権限を更新
                Task {
                    await updatePurchasedProducts()
                }

            case .restored:
                // 復元成功
                SKPaymentQueue.default().finishTransaction(transaction)
                Task {
                    await updatePurchasedProducts()
                }

            case .failed:
                // 購入失敗
                SKPaymentQueue.default().finishTransaction(transaction)

            case .deferred:
                // 承認待ち（Ask to Buy など）
                break

            case .purchasing:
                // 購入中
                break

            @unknown default:
                break
            }
        }
    }

    // 復元完了の通知
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        Task {
            await updatePurchasedProducts()
        }
    }

    // プロモーションオファーの署名リクエスト（サブスクリプション用）
    func paymentQueue(_ queue: SKPaymentQueue, shouldContinue transaction: SKPaymentTransaction, in store: SKStorefront) -> Bool {
        return true
    }
}

// MARK: - Extensions

extension Product {
    var localizedPrice: String {
        // Use the product's built-in display price if available
        return displayPrice
    }
}