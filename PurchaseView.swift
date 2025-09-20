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
                    
                    if let proProduct = purchaseManager.getProduct(for: "yokAppDev.quickMemoApp.pro") {
                        purchaseSection(for: proProduct)
                    }
                    
                    restoreSection
                }
                .padding()
            }
            .navigationTitle("QuickMemo Pro")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .alert("購入状況", isPresented: $showingAlert) {
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
            
            Text("すべての機能をアンロックして、より効率的にメモを管理しましょう")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pro機能")
                .font(.headline)
                .fontWeight(.semibold)
            
            FeatureRow(icon: "infinity", title: "無制限のメモ", description: "メモ数の制限なし")
            FeatureRow(icon: "folder.badge.plus", title: "無制限のカテゴリ", description: "カテゴリを自由に作成")
            FeatureRow(icon: "tag.fill", title: "高度なタグ管理", description: "タグでメモを整理")
            FeatureRow(icon: "calendar.badge.plus", title: "カレンダー連携", description: "詳細なカレンダー設定")
            FeatureRow(icon: "link", title: "Deep Link", description: "他のアプリから直接メモ作成")
            FeatureRow(icon: "square.stack.3d.up.fill", title: "Widget カスタマイズ", description: "ウィジェットの表示をカスタマイズ")
            FeatureRow(icon: "icloud.and.arrow.up", title: "データバックアップ", description: "データの安全な保存")
            FeatureRow(icon: "arrow.triangle.2.circlepath", title: "完全同期", description: "すべてのデバイスで同期")
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
            
            Text("一度の購入ですべての機能が永続的に利用可能")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var purchasedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            Text("購入済み")
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
                    Text("購入する - \(product.localizedPrice)")
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
    
    private var restoreSection: some View {
        VStack(spacing: 8) {
            Button("購入を復元") {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }
            .foregroundColor(.blue)
            
            Text("以前に購入した場合はここから復元できます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func handlePurchaseStateChange(_ state: PurchaseManager.PurchaseState) {
        switch state {
        case .purchased:
            alertMessage = "購入が完了しました！Pro機能をお楽しみください。"
            showingAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        case .failed(let error):
            alertMessage = "購入に失敗しました: \(error)"
            showingAlert = true
        case .cancelled:
            alertMessage = "購入がキャンセルされました。"
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