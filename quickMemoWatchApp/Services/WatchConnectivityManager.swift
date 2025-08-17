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
        default:
            break
        }
    }
}