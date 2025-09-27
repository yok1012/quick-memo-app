import Foundation
import StoreKit
import Combine

class WatchPurchaseManager: ObservableObject {
    static let shared = WatchPurchaseManager()

    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false


    private init() {
        checkPurchaseStatus()
    }

    func checkPurchaseStatus() {
        // App Groupから読み取る
        if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
            // 課金状態を確認
            isPro = sharedDefaults.bool(forKey: "isPurchased")
        }
    }

    func syncWithPhone() {
        // WatchConnectivityを使ってiPhoneから課金状態を同期
        WatchConnectivityManager.shared.requestPurchaseStatus()
    }

}