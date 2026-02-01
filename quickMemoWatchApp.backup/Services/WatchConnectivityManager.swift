import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var pendingMemos: [[String: Any]] = []
    
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
    
    func sendMemoToPhone(memoData: [String: Any]) {
        let session = WCSession.default
        
        if session.isReachable {
            session.sendMessage(["type": "newMemo", "data": memoData], replyHandler: nil) { error in
                print("Watch: メッセージ送信エラー: \(error)")
                self.storePendingMemo(memoData)
            }
        } else {
            storePendingMemo(memoData)
        }
    }
    
    private func storePendingMemo(_ memoData: [String: Any]) {
        pendingMemos.append(memoData)
        saveToUserDefaults()
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(pendingMemos, forKey: "pendingMemos")
    }
    
    private func loadFromUserDefaults() {
        if let saved = UserDefaults.standard.array(forKey: "pendingMemos") as? [[String: Any]] {
            pendingMemos = saved
        }
    }
    
    func syncPendingMemos() {
        guard !pendingMemos.isEmpty, WCSession.default.isReachable else { return }
        
        let memosToSync = pendingMemos
        pendingMemos.removeAll()
        saveToUserDefaults()
        
        for memoData in memosToSync {
            WCSession.default.sendMessage(["type": "newMemo", "data": memoData], replyHandler: nil) { error in
                print("Watch: 保留メモ同期エラー: \(error)")
                self.pendingMemos.append(memoData)
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if self.isReachable {
                self.loadFromUserDefaults()
                self.syncPendingMemos()
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if self.isReachable {
                self.syncPendingMemos()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "syncRequest":
            syncPendingMemos()
        case "categoriesUpdate":
            if let data = message["data"] as? [[String: Any]] {
                updateCategories(data)
            }
        case "memosUpdate":
            if let data = message["data"] as? [[String: Any]] {
                updateMemos(data)
            }
        default:
            break
        }
    }

    private func updateCategories(_ categoriesData: [[String: Any]]) {
        let categories = categoriesData.compactMap { data -> WatchCategory? in
            guard let name = data["name"] as? String,
                  let icon = data["icon"] as? String,
                  let color = data["color"] as? String else { return nil }

            return WatchCategory(
                id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
                name: name,
                icon: icon,
                color: color
            )
        }

        DispatchQueue.main.async {
            WatchDataManager.shared.updateFromPhone(
                memos: WatchDataManager.shared.memos,
                categories: categories
            )
        }
    }

    private func updateMemos(_ memosData: [[String: Any]]) {
        let memos = memosData.compactMap { data -> WatchMemo? in
            guard let content = data["content"] as? String,
                  let category = data["category"] as? String else { return nil }

            let title = data["title"] as? String ?? ""
            let timestamp = data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970

            return WatchMemo(
                id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
                title: title,
                content: content,
                category: category,
                createdAt: Date(timeIntervalSince1970: timestamp)
            )
        }

        DispatchQueue.main.async {
            WatchDataManager.shared.updateFromPhone(
                memos: memos,
                categories: WatchDataManager.shared.categories
            )
        }
    }
}