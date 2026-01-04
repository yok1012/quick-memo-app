import Foundation
import SwiftUI

/// 報酬型広告によるメモ・カテゴリー追加枠を管理するマネージャー
@MainActor
class RewardManager: ObservableObject {
    static let shared = RewardManager()

    // MARK: - Published Properties

    /// 現在の報酬メモ残数
    @Published private(set) var rewardMemoCount: Int = 0

    /// 現在の報酬カテゴリー残数
    @Published private(set) var rewardCategoryCount: Int = 0

    /// 広告の読み込み状態
    @Published var isAdLoading: Bool = false

    /// 広告の準備状態
    @Published var isAdReady: Bool = false

    /// エラーメッセージ
    @Published var errorMessage: String? = nil

    // MARK: - Constants

    /// 動画1回視聴で得られるメモ枠
    static let memosPerReward: Int = 10

    /// 動画1回視聴で得られるカテゴリー枠
    static let categoriesPerReward: Int = 1

    // MARK: - UserDefaults Keys

    private let rewardMemoCountKey = "reward_memo_count"
    private let rewardCategoryCountKey = "reward_category_count"

    // MARK: - App Group

    private let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
    private var userDefaults: UserDefaults

    // MARK: - Initialization

    private init() {
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.userDefaults = groupDefaults
        } else {
            self.userDefaults = UserDefaults.standard
        }

        loadRewardStatus()
    }

    // MARK: - Public Methods

    /// 報酬メモが利用可能かどうか
    var hasRewardMemos: Bool {
        return rewardMemoCount > 0
    }

    /// 報酬カテゴリーが利用可能かどうか
    var hasRewardCategories: Bool {
        return rewardCategoryCount > 0
    }

    /// 広告を視聴可能かどうか（常にtrue）
    var canWatchAd: Bool {
        return true
    }

    /// 報酬メモを1つ消費する
    /// - Returns: 消費に成功した場合はtrue
    func consumeRewardMemo() -> Bool {
        guard hasRewardMemos else {
            return false
        }

        rewardMemoCount -= 1
        saveRewardStatus()

        print("🎁 Consumed 1 reward memo. Remaining: \(rewardMemoCount)")
        return true
    }

    /// 報酬カテゴリーを1つ消費する
    /// - Returns: 消費に成功した場合はtrue
    func consumeRewardCategory() -> Bool {
        guard hasRewardCategories else {
            return false
        }

        rewardCategoryCount -= 1
        saveRewardStatus()

        print("🎁 Consumed 1 reward category. Remaining: \(rewardCategoryCount)")
        return true
    }

    /// 広告視聴完了時にメモ報酬を付与する
    func grantMemoReward() {
        let granted = RewardManager.memosPerReward
        rewardMemoCount += granted

        saveRewardStatus()

        print("🎉 Granted \(granted) reward memos. Total: \(rewardMemoCount)")

        // 通知を送信
        NotificationCenter.default.post(name: Notification.Name("RewardGranted"), object: nil, userInfo: ["type": "memo", "count": granted])
    }

    /// 広告視聴完了時にカテゴリー報酬を付与する
    func grantCategoryReward() {
        let granted = RewardManager.categoriesPerReward
        rewardCategoryCount += granted

        saveRewardStatus()

        print("🎉 Granted \(granted) reward categories. Total: \(rewardCategoryCount)")

        // 通知を送信
        NotificationCenter.default.post(name: Notification.Name("RewardGranted"), object: nil, userInfo: ["type": "category", "count": granted])
    }

    /// 広告視聴完了時に報酬を付与する（メモ枠のみ - 後方互換性のため）
    func grantReward() {
        grantMemoReward()
    }

    /// メモ作成時に報酬メモまたは通常枠を使用できるか確認
    /// - Parameter currentMemoCount: 現在のメモ数
    /// - Parameter isProVersion: Pro版かどうか
    /// - Returns: メモを作成できる場合はtrue
    func canCreateMemo(currentMemoCount: Int, isProVersion: Bool) -> Bool {
        // Pro版は無制限
        if isProVersion {
            return true
        }

        // 無料版の制限（100個）に達していない
        if currentMemoCount < 100 {
            return true
        }

        // 報酬メモがあれば作成可能
        return hasRewardMemos
    }

    /// メモ作成時にどのタイプの枠を使用するか決定
    /// - Parameter currentMemoCount: 現在のメモ数
    /// - Parameter isProVersion: Pro版かどうか
    /// - Returns: 使用する枠のタイプ
    func determineMemoSlotType(currentMemoCount: Int, isProVersion: Bool) -> MemoSlotType {
        if isProVersion {
            return .proUnlimited
        }

        if currentMemoCount < 100 {
            return .freeSlot
        }

        if hasRewardMemos {
            return .rewardSlot
        }

        return .limitReached
    }

    /// 報酬メモ使用してメモを作成する準備
    /// - Returns: 報酬メモを使用した場合はtrue
    func useRewardMemoIfNeeded(currentMemoCount: Int, isProVersion: Bool) -> Bool {
        let slotType = determineMemoSlotType(currentMemoCount: currentMemoCount, isProVersion: isProVersion)

        if slotType == .rewardSlot {
            return consumeRewardMemo()
        }

        return false
    }

    // MARK: - Category Slot Methods

    /// カテゴリー作成時に報酬カテゴリーまたは通常枠を使用できるか確認
    /// - Parameter currentCategoryCount: 現在のカテゴリー数
    /// - Parameter isProVersion: Pro版かどうか
    /// - Returns: カテゴリーを作成できる場合はtrue
    func canCreateCategory(currentCategoryCount: Int, isProVersion: Bool) -> Bool {
        // Pro版は無制限
        if isProVersion {
            return true
        }

        // 無料版の制限（5個）に達していない
        if currentCategoryCount < 5 {
            return true
        }

        // 報酬カテゴリーがあれば作成可能
        return hasRewardCategories
    }

    /// カテゴリー作成時にどのタイプの枠を使用するか決定
    /// - Parameter currentCategoryCount: 現在のカテゴリー数
    /// - Parameter isProVersion: Pro版かどうか
    /// - Returns: 使用する枠のタイプ
    func determineCategorySlotType(currentCategoryCount: Int, isProVersion: Bool) -> CategorySlotType {
        if isProVersion {
            return .proUnlimited
        }

        if currentCategoryCount < 5 {
            return .freeSlot
        }

        if hasRewardCategories {
            return .rewardSlot
        }

        return .limitReached
    }

    /// 報酬カテゴリー使用してカテゴリーを作成する準備
    /// - Returns: 報酬カテゴリーを使用した場合はtrue
    func useRewardCategoryIfNeeded(currentCategoryCount: Int, isProVersion: Bool) -> Bool {
        let slotType = determineCategorySlotType(currentCategoryCount: currentCategoryCount, isProVersion: isProVersion)

        if slotType == .rewardSlot {
            return consumeRewardCategory()
        }

        return false
    }

    // MARK: - Private Methods

    private func loadRewardStatus() {
        rewardMemoCount = userDefaults.integer(forKey: rewardMemoCountKey)
        rewardCategoryCount = userDefaults.integer(forKey: rewardCategoryCountKey)
        print("📦 Loaded reward status: memos=\(rewardMemoCount), categories=\(rewardCategoryCount)")
    }

    private func saveRewardStatus() {
        userDefaults.set(rewardMemoCount, forKey: rewardMemoCountKey)
        userDefaults.set(rewardCategoryCount, forKey: rewardCategoryCountKey)
        userDefaults.synchronize()
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// デバッグ用：報酬メモを追加
    func debugAddRewardMemos(_ count: Int) {
        rewardMemoCount += count
        saveRewardStatus()
        print("🔧 DEBUG: Added \(count) reward memos. Total: \(rewardMemoCount)")
    }

    /// デバッグ用：報酬カテゴリーを追加
    func debugAddRewardCategories(_ count: Int) {
        rewardCategoryCount += count
        saveRewardStatus()
        print("🔧 DEBUG: Added \(count) reward categories. Total: \(rewardCategoryCount)")
    }

    /// デバッグ用：報酬をリセット
    func debugResetRewards() {
        rewardMemoCount = 0
        rewardCategoryCount = 0
        saveRewardStatus()
        print("🔧 DEBUG: Reward status reset")
    }
    #endif
}

// MARK: - Memo Slot Type

enum MemoSlotType {
    case proUnlimited    // Pro版（無制限）
    case freeSlot        // 無料版の通常枠
    case rewardSlot      // 報酬による追加枠
    case limitReached    // 制限に達した（メモ作成不可）

    var description: String {
        switch self {
        case .proUnlimited:
            return "Pro版（無制限）"
        case .freeSlot:
            return "無料版の通常枠"
        case .rewardSlot:
            return "報酬による追加枠"
        case .limitReached:
            return "制限に達しました"
        }
    }
}

// MARK: - Category Slot Type

enum CategorySlotType {
    case proUnlimited    // Pro版（無制限）
    case freeSlot        // 無料版の通常枠
    case rewardSlot      // 報酬による追加枠
    case limitReached    // 制限に達した（カテゴリー作成不可）

    var description: String {
        switch self {
        case .proUnlimited:
            return "Pro版（無制限）"
        case .freeSlot:
            return "無料版の通常枠"
        case .rewardSlot:
            return "報酬による追加枠"
        case .limitReached:
            return "制限に達しました"
        }
    }
}
