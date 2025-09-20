import StoreKit
import SwiftUI

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // Product identifiers
    private let proVersionID = "yokAppDev.quickMemoApp.pro"
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isProVersion: Bool = false
    @Published var purchaseState: PurchaseState = .notStarted
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
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
            let products = try await Product.products(for: [proVersionID])
            
            await MainActor.run {
                self.products = products
            }
        } catch {
            print("Failed to load products: \(error)")
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
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Failed to restore purchases: \(error)")
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
            print("Unverified transaction: \(error)")
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchasedProductIDs: Set<String> = []
        
        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            switch verificationResult {
            case let .verified(transaction):
                if transaction.revocationDate == nil {
                    purchasedProductIDs.insert(transaction.productID)
                }
            case .unverified:
                // Ignore unverified transactions
                break
            }
        }
        
        await MainActor.run {
            self.purchasedProductIDs = purchasedProductIDs
            self.isProVersion = purchasedProductIDs.contains(proVersionID)
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
        return currentCount < 50 // Free users limited to 50 memos
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