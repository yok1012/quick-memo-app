//
//  quickMemoAppApp.swift
//  quickMemoApp
//
//  Created by kiichi yokokawa on 2025/08/18.
//

import SwiftUI

@main
struct quickMemoAppApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var watchConnectivityManager = iOSWatchConnectivityManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var adManager = AdMobManager.shared
    @StateObject private var rewardManager = RewardManager.shared

    init() {
        // アプリ起動直後にPurchaseManagerを初期化してトランザクション監視を開始
        // @StateObjectは自動的に初期化されるが、明示的にアクセスして確実に初期化
        _ = PurchaseManager.shared

        // DataManagerを確実に初期化（カテゴリーの読み込みを保証）
        _ = DataManager.shared

        // AdMob SDKを初期化（Pro版以外の場合）
        if !PurchaseManager.shared.isProVersion {
            AdMobManager.shared.initialize()
        }

        // 初期化状態をログ出力
        print("🚀 App initialization - DataManager categories: \(DataManager.shared.categories.count)")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .id(localizationManager.refreshID)  // Force refresh when language changes
                .environmentObject(deepLinkManager)
                .environmentObject(dataManager)  // DataManagerを環境オブジェクトとして提供
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
                .onAppear {
                    // 🚨 重要: iCloud復元処理が完了してからカテゴリーの状態を確認
                    // iCloud復元が完了する前にdiagnoseAndRepairCategoriesを呼ぶと、
                    // デフォルトカテゴリーが作成されてiCloud復元がスキップされる
                    Task { @MainActor in
                        // iCloud復元処理の完了を待機
                        while !dataManager.isCloudRestoreComplete {
                            print("⏳ Waiting for iCloud restore to complete...")
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                        }

                        // iCloud復元完了後にカテゴリーの状態を確認
                        if dataManager.categories.isEmpty {
                            print("⚠️ App onAppear: Categories are empty after iCloud restore, attempting repair...")
                            dataManager.diagnoseAndRepairCategories()
                        } else {
                            print("✅ App onAppear: \(dataManager.categories.count) categories available")
                        }
                    }
                    
                    // CloudKitスキーマの初期化（開発環境のみ）
                    #if DEBUG
                    Task {
                        await CloudKitSchemaHelper.createSchemaIfNeeded()
                        // CloudKit設定のデバッグ情報を出力
                        CloudKitManager.shared.printDebugInfo()
                        // iCloud利用可能性をチェック
                        let isAvailable = await CloudKitManager.shared.isiCloudAvailable()
                        print("🔍 iCloud Available at startup: \(isAvailable)")
                    }
                    #endif

                    // Pro版で通知が有効な場合、通知権限をチェックしてからスケジュール
                    if purchaseManager.isProVersion && notificationManager.isNotificationEnabled {
                        notificationManager.checkPermission { granted in
                            if granted {
                                // 少し遅延を入れてスケジュール（初期化完了を待つ）
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    // 再度Pro版をチェック
                                    if purchaseManager.isProVersion {
                                        notificationManager.scheduleNotifications()
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
}

// Deep Link Manager
class DeepLinkManager: ObservableObject {
    @Published var pendingAction: DeepLinkAction?
    @Published var showPurchaseView = false
    @Published var showSettingsView = false

    enum DeepLinkAction: Equatable {
        case openApp
        case addMemo(category: String)
        case showPurchase
        case showSettings
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "quickmemo" else { return }

        switch url.host {
        case "open":
            pendingAction = .openApp
        case "add":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let categoryItem = components.queryItems?.first(where: { $0.name == "category" }),
               let categoryName = categoryItem.value?.removingPercentEncoding {
                pendingAction = .addMemo(category: categoryName)
            }
        case "purchase":
            // 購入画面を表示
            pendingAction = .showPurchase
            showPurchaseView = true
        case "settings":
            // 設定画面を表示
            pendingAction = .showSettings
            showSettingsView = true
        default:
            break
        }
    }

    func clearPendingAction() {
        pendingAction = nil
    }
}
