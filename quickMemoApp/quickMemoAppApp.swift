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

    var body: some Scene {
        WindowGroup {
            MainView()
                .id(localizationManager.refreshID)  // Force refresh when language changes
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
                .onAppear {
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
