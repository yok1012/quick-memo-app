import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    featuresSection
                    
                    if !purchaseManager.products.isEmpty {
                        productsSection
                    } else {
                        noProductsView
                    }

                    legalSection
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
    
    private var productsSection: some View {
        VStack(spacing: 16) {
            if purchaseManager.isProVersion {
                purchasedView
            } else {
                // 商品を種類別に表示（月額を先に、買い切りを後に）
                ForEach(sortedProducts(), id: \.id) { product in
                    purchaseButton(for: product)

                    // 買い切りライセンスの直下に購入を復元ボタンを配置
                    if product.id == "yokAppDev.quickMemoApp.pro" {
                        // 購入を復元ボタン
                        Button(action: {
                            Task {
                                await purchaseManager.restorePurchases()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle")
                                    .font(.body)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("purchase_restore".localized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("purchase_restore_subtitle".localized)
                                        .font(.caption2)
                                        .opacity(0.8)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }
                }

                // サブスクリプション必須情報の表示
                subscriptionTermsView

                HStack(spacing: 16) {
                    Link("privacy_policy".localized, destination: URL(string: "https://yok1012.github.io/quickMemoPrivacypolicy/")!)
                    Link("terms_of_use".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.caption)
            }
        }
    }

    private func sortedProducts() -> [Product] {
        purchaseManager.products.sorted { product1, product2 in
            // 月額サブスクを先に表示
            if product1.id == "com.yokAppDev.quickMemoApp.pro.month" {
                return true
            } else if product2.id == "com.yokAppDev.quickMemoApp.pro.month" {
                return false
            }
            // 価格でソート
            return product1.price < product2.price
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
        VStack(spacing: 8) {
            // 商品タイプの表示
            HStack {
                if product.id == "com.yokAppDev.quickMemoApp.pro.month" {
                    Label("purchase_monthly_subscription".localized, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if product.id == "yokAppDev.quickMemoApp.pro" {
                    Label("purchase_onetime".localized, systemImage: "infinity")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
            }
            .padding(.horizontal)

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
                        VStack(spacing: 4) {
                            // 商品名
                            Text(product.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            // 動的に取得した価格を表示
                            Text(product.displayPrice)
                                .font(.headline)
                                .fontWeight(.bold)

                            // サブスクの場合は期間を表示
                            if product.subscription != nil {
                                Text(getPeriodText(for: product))
                                    .font(.caption2)
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(product.id == "yokAppDev.quickMemoApp.pro" ? Color.green : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(purchaseManager.purchaseState == .purchasing)
        }
    }

    private func getPeriodText(for product: Product) -> String {
        guard let subscription = product.subscription else { return "" }

        switch subscription.subscriptionPeriod.unit {
        case .day:
            return "\(subscription.subscriptionPeriod.value) " + "purchase_period_day".localized
        case .week:
            return "\(subscription.subscriptionPeriod.value) " + "purchase_period_week".localized
        case .month:
            return "\(subscription.subscriptionPeriod.value) " + "purchase_period_month".localized
        case .year:
            return "\(subscription.subscriptionPeriod.value) " + "purchase_period_year".localized
        @unknown default:
            return ""
        }
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
    
    private var legalSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            // サブスクリプション管理の詳細説明
            VStack(alignment: .leading, spacing: 8) {
                Text("subscription_info_title".localized)
                    .font(.footnote)
                    .fontWeight(.semibold)

                Text("subscription_info_auto_renew".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("subscription_info_cancel".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("subscription_info_manage".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 法的リンク
            HStack(spacing: 16) {
                Link("privacy_policy".localized, destination: URL(string: "https://yok1012.github.io/quickMemoPrivacypolicy/")!)
                Link("terms_of_use".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.footnote)
        }
    }

    private var subscriptionTermsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 月額サブスクリプションの詳細情報
            if let monthlyProduct = purchaseManager.products.first(where: { $0.id == "com.yokAppDev.quickMemoApp.pro.month" }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("subscription_monthly_details".localized)
                        .font(.caption)
                        .fontWeight(.medium)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(String(format: "subscription_price_format".localized, monthlyProduct.displayPrice))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("subscription_auto_renew_monthly".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Text("subscription_notice_detailed".localized)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
