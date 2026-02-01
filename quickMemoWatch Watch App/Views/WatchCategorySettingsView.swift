import SwiftUI

struct WatchCategorySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = WatchDataManager.shared
    @StateObject private var purchaseManager = WatchPurchaseManager.shared

    @State private var selectedCategories: Set<String> = []
    @State private var showingProAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 課金状態表示
                    HStack {
                        Image(systemName: purchaseManager.isPro ? "crown.fill" : "lock.fill")
                            .foregroundColor(purchaseManager.isPro ? .yellow : .gray)
                            .font(.caption)
                        Text(purchaseManager.isPro ? "Pro" : "Free")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    if purchaseManager.isPro {
                        proSettingsView
                    } else {
                        freeSettingsView
                    }

                    Spacer(minLength: 20)

                }
                .padding()
            }
            .navigationTitle("カテゴリー設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadSelectedCategories()
            purchaseManager.syncWithPhone()
        }
    }

    private var freeSettingsView: some View {
        VStack(spacing: 12) {
            Text("無料版")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("以下のカテゴリーが使用できます")
                .font(.caption2)
                .multilineTextAlignment(.center)

            // デフォルトカテゴリーの表示
            ForEach(getDefaultCategories(), id: \.name) { category in
                HStack {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .frame(width: 20)
                    Text(category.name)
                        .font(.caption)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
            }

            Button(action: {
                showingProAlert = true
            }) {
                Label("Pro版にアップグレード", systemImage: "crown")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .alert("Pro版へのアップグレード", isPresented: $showingProAlert) {
                Button("iPhoneで購入画面を開く") {
                    // iPhoneに購入画面を開くメッセージを送信
                    WatchConnectivityManager.shared.sendMessageToPhone(["action": "openPurchase"])
                }
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("iPhoneでPro版を購入してください")
            }
        }
    }

    private var proSettingsView: some View {
        VStack(spacing: 12) {
            Text("Pro版")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("選択されたカテゴリー")
                .font(.caption2)
                .foregroundColor(.secondary)

            // iPhoneで選択されたカテゴリーを表示（読み取り専用）
            if selectedCategories.isEmpty {
                Text("iPhoneで設定してください")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding()
            } else {
                ForEach(Array(selectedCategories), id: \.self) { categoryName in
                    if let category = dataManager.categories.first(where: { $0.name == categoryName }) {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.caption)
                                .frame(width: 20)
                                .foregroundColor(Color(hex: category.color))
                            Text(category.name)
                                .font(.caption)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.2))
                        )
                    }
                }
            }

            VStack(spacing: 4) {
                Image(systemName: "iphone")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("カテゴリーの変更はiPhoneから行ってください")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
        }
    }

    private func getDefaultCategories() -> [WatchCategory] {
        return [
            WatchCategory(name: "仕事", icon: "briefcase", color: "007AFF"),
            WatchCategory(name: "プライベート", icon: "house", color: "34C759"),
            WatchCategory(name: "その他", icon: "folder", color: "8E8E93")
        ]
    }

    private func loadSelectedCategories() {
        if purchaseManager.isPro {
            // App Groupから読み取り（iPhoneで設定されたもの）
            if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp"),
               let saved = sharedDefaults.array(forKey: "watchSelectedCategories") as? [String] {
                selectedCategories = Set(saved)
            } else {
                // デフォルト選択
                selectedCategories = Set(dataManager.categories.prefix(4).map { $0.name })
            }
        }
    }
}