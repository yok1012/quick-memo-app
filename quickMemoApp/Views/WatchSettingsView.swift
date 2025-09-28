import SwiftUI

struct WatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var watchConnectivity = iOSWatchConnectivityManager.shared

    @State private var selectedCategories: Set<String> = []
    @State private var showingUpgradeAlert = false

    // デバッグモード対応
    private var isProVersion: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugProMode") {
            return true
        }
        #endif
        return purchaseManager.isPurchased("pro.quickmemo.monthly")
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "applewatch")
                            .foregroundColor(.blue)
                        Text("Apple Watch設定")
                            .font(.headline)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: watchConnectivity.isWatchAppInstalled ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(watchConnectivity.isWatchAppInstalled ? .green : .gray)
                        Text(watchConnectivity.isWatchAppInstalled ? "Watch Appインストール済み" : "Watch App未インストール")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: watchConnectivity.isReachable ? "wifi" : "wifi.slash")
                            .foregroundColor(watchConnectivity.isReachable ? .green : .gray)
                        Text(watchConnectivity.isReachable ? "接続中" : "未接続")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("カテゴリー設定")) {
                    if isProVersion {
                        proSettingsSection
                    } else {
                        freeSettingsSection
                    }
                }

                if isProVersion && selectedCategories.count > 0 {
                    Section {
                        Button(action: saveAndSync) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Watchに同期")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }

                #if DEBUG
                Section(header: Text("デバッグ設定")) {
                    HStack {
                        Toggle(isOn: Binding<Bool>(
                            get: { UserDefaults.standard.bool(forKey: "debugProMode") },
                            set: { value in
                                UserDefaults.standard.set(value, forKey: "debugProMode")
                                // App Groupにも保存
                                if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
                                    sharedDefaults.set(value, forKey: "debugProMode")
                                }
                                // Watchに同期
                                iOSWatchConnectivityManager.shared.sendPurchaseStatusToWatch()
                                loadSelectedCategories()
                            }
                        )) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(.orange)
                                Text("Pro版として動作")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                #endif
            }
            .navigationTitle("Watch設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        saveAndSync()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSelectedCategories()
        }
    }

    private var freeSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("無料版では以下のカテゴリーが使用できます：")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(defaultFreeCategories, id: \.self) { categoryName in
                HStack {
                    Image(systemName: getCategoryIcon(categoryName))
                        .frame(width: 20)
                        .foregroundColor(.blue)
                    Text(categoryName)
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }

            Button(action: {
                showingUpgradeAlert = true
            }) {
                Label("Pro版でカテゴリーをカスタマイズ", systemImage: "crown")
                    .foregroundColor(.orange)
            }
            .padding(.top, 8)
            .alert("Pro版へアップグレード", isPresented: $showingUpgradeAlert) {
                Button("購入画面へ", action: openPurchaseView)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("Pro版では最大4つのカテゴリーを自由に選択できます")
            }
        }
    }

    private var proSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watch Appで使用するカテゴリーを選択（最大4個）")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(dataManager.categories) { category in
                HStack {
                    Image(systemName: category.icon)
                        .frame(width: 20)
                        .foregroundColor(Color(hex: category.color))

                    Text(category.name)

                    Spacer()

                    if selectedCategories.contains(category.name) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleCategory(category.name)
                }
                .padding(.vertical, 4)
            }

            if selectedCategories.count == 4 {
                Text("最大数に達しました")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }

    private func getCategoryIcon(_ name: String) -> String {
        let key = LocalizedCategories.baseKey(forLocalizedName: name) ?? name
        return LocalizedCategories.iconName(for: key)
    }

    private var defaultFreeCategories: [String] {
        ["work", "personal", "other"].map { LocalizedCategories.localizedName(for: $0) }
    }

    private func loadSelectedCategories() {
        if isProVersion {
            if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp"),
               let saved = sharedDefaults.array(forKey: "watchSelectedCategories") as? [String] {
                selectedCategories = Set(saved)
            } else {
                // デフォルトで最初の4つを選択
                selectedCategories = Set(dataManager.categories.prefix(4).map { $0.name })
            }
        }
    }

    private func toggleCategory(_ name: String) {
        if selectedCategories.contains(name) {
            selectedCategories.remove(name)
        } else {
            if selectedCategories.count < 4 {
                selectedCategories.insert(name)
            }
        }
    }

    private func saveAndSync() {
        if isProVersion {
            // App Groupに保存
            if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
                sharedDefaults.set(Array(selectedCategories), forKey: "watchSelectedCategories")

                // デバッグモードの状態も保存
                #if DEBUG
                sharedDefaults.set(UserDefaults.standard.bool(forKey: "debugProMode"), forKey: "debugProMode")
                #endif
            }

            // Watchに同期
            sendCategoriesToWatch()

            // 課金状態も同期
            iOSWatchConnectivityManager.shared.sendPurchaseStatusToWatch()
        }
    }

    private func sendCategoriesToWatch() {
        let message: [String: Any] = [
            "type": "watchCategoriesUpdate",
            "categories": Array(selectedCategories)
        ]

        if watchConnectivity.isReachable {
            // 直接送信
            iOSWatchConnectivityManager.shared.sendCategoriesToWatch()
        }

        // バックグラウンド配信用にも保存
        if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
            sharedDefaults.set(Array(selectedCategories), forKey: "watchSelectedCategories")
        }
    }

    private func openPurchaseView() {
        // PurchaseViewを表示する実装
    }
}

#Preview {
    WatchSettingsView()
}
