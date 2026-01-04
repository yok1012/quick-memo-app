import Foundation
import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

/// AdMob広告を管理するマネージャー
@MainActor
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()

    // MARK: - Published Properties

    /// 報酬型広告が準備できているか
    @Published var isRewardedAdReady: Bool = false

    /// 広告を読み込み中か
    @Published var isLoading: Bool = false

    /// エラーメッセージ
    @Published var errorMessage: String? = nil

    /// ATT（App Tracking Transparency）の状態
    @Published var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    /// 報酬型広告オブジェクト
    private var rewardedAd: RewardedAd?

    /// 広告表示完了時のコールバック
    private var rewardCallback: ((Bool) -> Void)?

    // MARK: - Ad Unit IDs

    /// 報酬型広告のユニットID
    private var rewardedAdUnitID: String {
        #if DEBUG
        // テスト用広告ID（Google公式のテストID）
        return "ca-app-pub-3940256099942544/1712485313"
        #else
        // 本番用広告ID
        return "ca-app-pub-9111455054322479/1259129743"
        #endif
    }

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// AdMob SDKを初期化
    func initialize() {
        print("📺 Initializing AdMob SDK...")

        // Google Mobile Ads SDKを初期化
        MobileAds.shared.start { [weak self] status in
            print("✅ AdMob SDK initialized")

            // 各アダプターの状態をログ出力
            let adapters = status.adapterStatusesByClassName
            for (adapter, adapterStatus) in adapters {
                print("   Adapter: \(adapter), State: \(adapterStatus.state.rawValue), Latency: \(adapterStatus.latency)")
            }

            // 初期化完了後に広告をプリロード
            Task { @MainActor in
                await self?.loadRewardedAd()
            }
        }
    }

    /// ATT（App Tracking Transparency）の許可をリクエスト
    func requestTrackingAuthorization() async {
        // iOS 14以降でのみATTを要求
        if #available(iOS 14, *) {
            let status = await ATTrackingManager.requestTrackingAuthorization()
            await MainActor.run {
                self.trackingAuthorizationStatus = status

                switch status {
                case .authorized:
                    print("✅ Tracking authorized")
                case .denied:
                    print("❌ Tracking denied")
                case .notDetermined:
                    print("⏳ Tracking not determined")
                case .restricted:
                    print("🚫 Tracking restricted")
                @unknown default:
                    print("❓ Unknown tracking status")
                }
            }
        }
    }

    /// ATTの現在の状態を取得
    func checkTrackingAuthorizationStatus() {
        if #available(iOS 14, *) {
            trackingAuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus
        }
    }

    /// 報酬型広告を読み込む
    func loadRewardedAd() async {
        guard !isLoading else {
            print("⏳ Ad is already loading...")
            return
        }

        isLoading = true
        errorMessage = nil

        print("📥 Loading rewarded ad...")

        do {
            let ad = try await RewardedAd.load(
                with: rewardedAdUnitID,
                request: Request()
            )

            rewardedAd = ad
            rewardedAd?.fullScreenContentDelegate = self
            isRewardedAdReady = true
            isLoading = false

            print("✅ Rewarded ad loaded successfully")

        } catch {
            isLoading = false
            isRewardedAdReady = false
            errorMessage = error.localizedDescription

            print("❌ Failed to load rewarded ad: \(error.localizedDescription)")
        }
    }

    /// 報酬型広告を表示
    /// - Parameter completion: 広告表示完了時のコールバック（報酬が付与された場合はtrue）
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            print("❌ Rewarded ad not ready")
            completion(false)
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            completion(false)
            return
        }

        // トップのViewControllerを取得（モーダルが表示されている場合など）
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }

        rewardCallback = completion

        print("📺 Showing rewarded ad...")

        rewardedAd.present(from: topViewController) { [weak self] in
            guard let self = self else { return }

            // 報酬の情報を取得
            let reward = rewardedAd.adReward
            print("🎁 User earned reward: \(reward.amount) \(reward.type)")

            // RewardManagerに報酬を付与
            RewardManager.shared.grantReward()

            // コールバックを呼び出し
            self.rewardCallback?(true)
            self.rewardCallback = nil
        }
    }

    /// 広告が表示可能かどうか
    var canShowAd: Bool {
        return isRewardedAdReady
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// デバッグ用：広告準備状態をリセット
    func debugResetAdState() {
        rewardedAd = nil
        isRewardedAdReady = false
        isLoading = false
        errorMessage = nil
        print("🔧 DEBUG: Ad state reset")
    }

    /// デバッグ用：広告読み込みをシミュレート
    func debugSimulateAdLoad() {
        isRewardedAdReady = true
        print("🔧 DEBUG: Ad load simulated")
    }

    /// デバッグ用：報酬付与をシミュレート
    func debugSimulateReward() {
        RewardManager.shared.grantReward()
        print("🔧 DEBUG: Reward granted (simulated)")
    }
    #endif
}

// MARK: - FullScreenContentDelegate

extension AdMobManager: FullScreenContentDelegate {

    /// 広告が表示された時
    nonisolated func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("📺 Ad did record impression")
    }

    /// 広告表示が失敗した時
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Ad failed to present: \(error.localizedDescription)")

        Task { @MainActor in
            self.isRewardedAdReady = false
            self.errorMessage = error.localizedDescription
            self.rewardCallback?(false)
            self.rewardCallback = nil

            // 次の広告を読み込む
            await self.loadRewardedAd()
        }
    }

    /// 広告が閉じられた時
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("📺 Ad dismissed")

        Task { @MainActor in
            self.isRewardedAdReady = false

            // 次の広告をプリロード
            await self.loadRewardedAd()
        }
    }

    /// 広告がクリックされた時
    nonisolated func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("📺 Ad clicked")
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// 報酬型広告ボタンを表示するモディファイア
    @ViewBuilder
    func rewardedAdButton(
        isPresented: Binding<Bool>,
        onReward: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: isPresented.wrappedValue) { _, newValue in
                if newValue {
                    Task { @MainActor in
                        AdMobManager.shared.showRewardedAd { success in
                            if success {
                                onReward()
                            }
                            onDismiss()
                            isPresented.wrappedValue = false
                        }
                    }
                }
            }
        } else {
            self.onChange(of: isPresented.wrappedValue) { newValue in
                if newValue {
                    Task { @MainActor in
                        AdMobManager.shared.showRewardedAd { success in
                            if success {
                                onReward()
                            }
                            onDismiss()
                            isPresented.wrappedValue = false
                        }
                    }
                }
            }
        }
    }
}
