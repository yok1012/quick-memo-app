import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    featuresSection
                    
                    if let proProduct = purchaseManager.products.first {
                        purchaseSection(for: proProduct)
                    } else {
                        noProductsView
                    }
                    
                    restoreSection
                }
                .padding()
            }
            .navigationTitle("QuickMemo Pro")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .alert("purchase_status".localized, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: purchaseManager.purchaseState) { newState in
            handlePurchaseStateChange(newState)
        }
        .task {
            await purchaseManager.loadProducts()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("QuickMemo Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("purchase_unlock_description".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("purchase_pro_features".localized)
                .font(.headline)
                .fontWeight(.semibold)
            
            FeatureRow(icon: "infinity", title: "purchase_unlimited_memos".localized, description: "purchase_unlimited_memos_desc".localized)
            FeatureRow(icon: "folder.badge.plus", title: "purchase_unlimited_categories".localized, description: "purchase_unlimited_categories_desc".localized)
            FeatureRow(icon: "tag.fill", title: "purchase_unlimited_tags".localized, description: "purchase_unlimited_tags_desc".localized)
            FeatureRow(icon: "icloud.and.arrow.up", title: "purchase_icloud_sync".localized, description: "purchase_icloud_sync_desc".localized)
            FeatureRow(icon: "square.stack.3d.up.fill", title: "purchase_widget_customize".localized, description: "purchase_widget_customize_desc".localized)
            FeatureRow(icon: "applewatch", title: "purchase_watch_pro".localized, description: "purchase_watch_pro_desc".localized)
            FeatureRow(icon: "square.and.arrow.down.on.square", title: "purchase_data_export".localized, description: "purchase_data_export_desc".localized)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func purchaseSection(for product: Product) -> VStack<TupleView<(some View, some View)>> {
        VStack(spacing: 16) {
            if purchaseManager.isProVersion {
                purchasedView
            } else {
                purchaseButton(for: product)
            }
            
            Text("purchase_one_time".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var purchasedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            Text("purchase_completed".localized)
                .font(.headline)
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func purchaseButton(for product: Product) -> some View {
        Button(action: {
            Task {
                await purchaseManager.purchase(product)
            }
        }) {
            HStack {
                if case .purchasing = purchaseManager.purchaseState {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\("purchase_buy".localized) - \(product.localizedPrice)")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(purchaseManager.purchaseState == .purchasing)
    }
    
    private var noProductsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("purchase_no_products".localized)
                .font(.headline)

            Text("purchase_network_error".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("purchase_retry".localized) {
                Task {
                    await purchaseManager.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private var restoreSection: some View {
        VStack(spacing: 8) {
            Button("purchase_restore".localized) {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }
            .foregroundColor(.blue)

            Text("purchase_restore_description".localized)
                .font(.caption)
                .foregroundColor(.secondary)

        }
    }
    
    private func handlePurchaseStateChange(_ state: PurchaseManager.PurchaseState) {
        switch state {
        case .purchased:
            alertMessage = "purchase_success_message".localized
            showingAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        case .failed(let error):
            alertMessage = "\("purchase_failed".localized): \(error)"
            showingAlert = true
        case .cancelled:
            alertMessage = "purchase_cancelled".localized
            showingAlert = true
        default:
            break
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    PurchaseView()
}