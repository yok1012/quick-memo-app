import Foundation
import WatchConnectivity
import SwiftUI

class iOSWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = iOSWatchConnectivityManager()

    @Published var isWatchAppInstalled = false
    @Published var isPaired = false
    @Published var isReachable = false
    @Published var receivedMemos: [QuickMemo] = []

    private override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // Send data to Watch
    func sendCategoriesToWatch() {
        guard WCSession.default.isWatchAppInstalled else { return }

        Task { @MainActor in
            let categories = DataManager.shared.categories.map { category in
                [
                    "id": category.id.uuidString,
                    "name": category.name,
                    "icon": category.icon,
                    "color": category.color,
                    "defaultTags": category.defaultTags,
                    "baseKey": category.baseKey ?? ""
                ]
            }

            let message: [String: Any] = ["type": "categoriesUpdate", "data": categories]

            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                }
            } else {
                // Transfer user info for background delivery
                WCSession.default.transferUserInfo(message)
            }
        }
    }

    func sendMemosToWatch() {
        guard WCSession.default.isWatchAppInstalled else { return }

        Task { @MainActor in
            // 最新の20件のメモのみ送信（Watchの容量を考慮）
            let memos = DataManager.shared.memos.prefix(20).map { memo in
                [
                    "id": memo.id.uuidString,
                    "title": memo.title,
                    "content": memo.content,
                    "category": memo.primaryCategory,
                    "createdAt": memo.createdAt.timeIntervalSince1970,
                    "tags": memo.tags
                ]
            }

            let message: [String: Any] = ["type": "memosUpdate", "data": memos]

            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                }
            } else {
                WCSession.default.transferUserInfo(message)
            }
        }
    }

    // Handle received memo from Watch
    private func handleReceivedMemo(_ memoData: [String: Any]) {
        let title = memoData["title"] as? String ?? ""
        let content = memoData["content"] as? String ?? ""
        let categoryName = memoData["category"] as? String ?? ""
        let categoryIdentifier = memoData["baseKey"] as? String ?? LocalizedCategories.baseKey(forLocalizedName: categoryName) ?? categoryName
        let category = categoryIdentifier.isEmpty
            ? LocalizedCategories.localizedName(for: "other")
            : LocalizedCategories.localizedName(for: categoryIdentifier)

        let tags = memoData["tags"] as? [String] ?? []

        let memo = QuickMemo(
            title: title,
            content: content,
            primaryCategory: category,
            tags: tags
        )

        // Add to DataManager
        Task { @MainActor in
            DataManager.shared.addMemo(memo)
            self.receivedMemos.append(memo)

            // Optional: Show notification
            self.showMemoNotification(memo: memo)
        }
    }

    private func showMemoNotification(memo: QuickMemo) {
        // Notification implementation if needed
    }
}

// MARK: - WCSessionDelegate for iOS
extension iOSWatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable

            // Send initial data if watch is reachable
            if self.isReachable {
                Task { @MainActor in
                    self.sendCategoriesToWatch()
                    self.sendMemosToWatch()
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS specific delegate method
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS specific delegate method
        // Reactivate session
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable

            // Sync data when watch becomes reachable
            if self.isReachable {
                Task { @MainActor in
                    self.sendCategoriesToWatch()
                    self.sendMemosToWatch()
                }
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
            replyHandler(["status": "received"])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(userInfo)
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        // アクションメッセージのチェック（typeなしのメッセージ）
        if let action = message["action"] as? String {
            switch action {
            case "openPurchase":
                // 購入画面を開く
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenPurchaseView"),
                    object: nil
                )
            case "openSettings":
                // 設定画面を開く
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenSettingsView"),
                    object: nil
                )
            default:
                break
            }
            return
        }

        // 既存のメッセージ処理
        guard let type = message["type"] as? String else { return }

        switch type {
        case "newMemo":
            if let data = message["data"] as? [String: Any] {
                handleReceivedMemo(data)
            }
        case "syncRequest":
            Task { @MainActor in
                sendCategoriesToWatch()
                sendMemosToWatch()
            }
        case "requestPurchaseStatus":
            sendPurchaseStatusToWatch()
        default:
            break
        }
    }

    func sendPurchaseStatusToWatch() {
        guard WCSession.default.isWatchAppInstalled else { return }

        Task { @MainActor in
            var isPro = PurchaseManager.shared.isProVersion

            #if DEBUG
            // デバッグモードの場合、デバッグ設定も確認
            if UserDefaults.standard.bool(forKey: "debugProMode") {
                isPro = true
            }
            #endif

            let message: [String: Any] = [
                "type": "purchaseStatusUpdate",
                "isPro": isPro
            ]

            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { error in
                }
            } else {
                WCSession.default.transferUserInfo(message)
            }

            // App Groupにも保存して同期
            if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
                sharedDefaults.set(isPro, forKey: "isPurchased")
            }
        }
    }
}

