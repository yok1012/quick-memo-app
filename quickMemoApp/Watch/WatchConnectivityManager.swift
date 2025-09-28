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
        Task { @MainActor in
            saveMemoLocally(memoData: memoData)
        }
    }
    
    func syncPendingMemos() {
        // iOSでは同期の必要なし
    }
    
    func setupiOSWatchConnectivity() {
        // 将来的にWatchConnectivity実装時用のプレースホルダー
        isReachable = true
    }
    
    @MainActor
    private func saveMemoLocally(memoData: [String: Any]) {
        let categoryName = memoData["category"] as? String ?? ""
        let identifier = memoData["baseKey"] as? String ?? LocalizedCategories.baseKey(forLocalizedName: categoryName) ?? categoryName
        let primaryCategory = identifier.isEmpty
            ? LocalizedCategories.localizedName(for: "other")
            : LocalizedCategories.localizedName(for: identifier)

        let title = memoData["title"] as? String ?? ""
        let content = memoData["content"] as? String ?? ""
        let tags = memoData["tags"] as? [String] ?? []

        let memo = QuickMemo(
            title: title,
            content: content,
            primaryCategory: primaryCategory,
            tags: tags
        )

        DataManager.shared.addMemo(memo)
    }
}
