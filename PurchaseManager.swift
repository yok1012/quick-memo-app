import StoreKit
import SwiftUI

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // Product identifiers - Sandboxテスト用に正しいProduct IDを設定
    // App Store Connect で設定した実際のProduct IDと一致させる必要があります
    // 複数の可能なProduct IDをサポート
    private let proVersionID = "yokAppDev.quickMemoApp.pro"
    private let alternativeProVersionID = "pro.quickmemo.monthly"
    private let allProductIDs: Set<String> = [
        "yokAppDev.quickMemoApp.pro",
        "pro.quickmemo.monthly",
        "com.yokAppDev.quickMemoApp.pro" // 別の可能性のあるID
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
    
    init() {
        // Start transaction update listener
        updateListenerTask = listenForTransactions()
        
        // Load products on initialization
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
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
        await MainActor.run {
            purchaseState = .purchasing
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case let .success(.verified(transaction)):
                // A successful purchase
                await transaction.finish()
                await updatePurchasedProducts()
                await MainActor.run {
                    purchaseState = .purchased
                }
                
            case let .success(.unverified(_, error)):
                // Successful purchase but transaction/receipt can't be verified
                await MainActor.run {
                    purchaseState = .failed(error.localizedDescription)
                }
                
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or approval from Ask to Buy
                await MainActor.run {
                    purchaseState = .notStarted
                }
                
            case .userCancelled:
                await MainActor.run {
                    purchaseState = .cancelled
                }
                
            @unknown default:
                await MainActor.run {
                    purchaseState = .notStarted
                }
            }
        } catch {
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
            // App Store と同期
            try await AppStore.sync()

            // 購入済み商品を更新
            await updatePurchasedProducts()

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

        var purchasedProductIDs: Set<String> = []
        var transactionCount = 0

        // すべての現在の権利を確認
        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            transactionCount += 1
            switch verificationResult {
            case let .verified(transaction):

                if let revocationDate = transaction.revocationDate {
                } else {
                    purchasedProductIDs.insert(transaction.productID)
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
        return currentCount < 3 // Free users limited to 3 categories
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
}

// MARK: - Extensions

extension Product {
    var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceFormatStyle.locale
        return formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
    }
}