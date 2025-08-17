import Foundation
import SwiftUI

// iOS向けの簡素化されたWatchConnectivityManager
class WatchConnectivityManager: ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var pendingMemos: [[String: Any]] = []
    
    private init() {}
    
    func sendMemoToPhone(memoData: [String: Any]) {
        // iOSでは同じデバイス内なので即座にメモを保存
        saveMemoLocally(memoData: memoData)
    }
    
    func syncPendingMemos() {
        // iOSでは同期の必要なし
    }
    
    func setupiOSWatchConnectivity() {
        // 将来的にWatchConnectivity実装時用のプレースホルダー
        isReachable = true
    }
    
    private func saveMemoLocally(memoData: [String: Any]) {
        let memo = QuickMemo(
            content: memoData["content"] as? String ?? "",
            primaryCategory: memoData["category"] as? String ?? "その他",
            tags: []
        )
        
        DataManager.shared.addMemo(memo)
        print("iOS: メモを保存しました")
    }
}