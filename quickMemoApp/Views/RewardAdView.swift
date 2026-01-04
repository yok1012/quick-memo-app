import SwiftUI

/// 報酬の種類
enum RewardType {
    case memo
    case category
}

/// 報酬型広告の視聴を促すビュー
struct RewardAdView: View {
    @ObservedObject private var rewardManager = RewardManager.shared
    @ObservedObject private var adManager = AdMobManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingAd = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var grantedCount: Int = 0
    @State private var selectedRewardType: RewardType = .memo
    @State private var successRewardType: RewardType = .memo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダーイラスト
                    headerSection

                    // 報酬タイプ選択
                    rewardTypePickerSection

                    // 報酬の説明
                    rewardDescriptionSection

                    // 現在の状態
                    currentStatusSection

                    // 広告視聴ボタン
                    watchAdButtonSection

                    // Pro版への誘導
                    proUpgradeSection

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("reward_ad_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .alert(successAlertTitle, isPresented: $showingSuccessAlert) {
                Button("ok".localized, role: .cancel) {}
            } message: {
                Text(successAlertMessage)
            }
            .alert("reward_error_title".localized, isPresented: $showingErrorAlert) {
                Button("ok".localized, role: .cancel) {}
            } message: {
                Text(adManager.errorMessage ?? "reward_error_unknown".localized)
            }
        }
        .onAppear {
            // ATTの状態を確認
            adManager.checkTrackingAuthorizationStatus()

            // 広告をプリロード
            if !adManager.isRewardedAdReady && !adManager.isLoading {
                Task {
                    await adManager.loadRewardedAd()
                }
            }
        }
    }

    private var successAlertTitle: String {
        switch successRewardType {
        case .memo:
            return "reward_success_title".localized
        case .category:
            return "reward_category_success_title".localized
        }
    }

    private var successAlertMessage: String {
        switch successRewardType {
        case .memo:
            return String(format: "reward_success_message".localized, grantedCount)
        case .category:
            return String(format: "reward_category_success_message".localized, grantedCount)
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gift.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("reward_ad_headline".localized)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var rewardTypePickerSection: some View {
        VStack(spacing: 12) {
            Text("reward_select_type".localized)
                .font(.headline)

            Picker("reward_type".localized, selection: $selectedRewardType) {
                Text("reward_type_memo".localized).tag(RewardType.memo)
                Text("reward_type_category".localized).tag(RewardType.category)
            }
            .pickerStyle(.segmented)
        }
    }

    private var rewardDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(rewardDescriptionText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                rewardFeatureRow(
                    icon: rewardFeatureIcon,
                    color: rewardFeatureColor,
                    title: rewardFeatureTitle,
                    description: rewardFeatureDescription
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var rewardDescriptionText: String {
        switch selectedRewardType {
        case .memo:
            return "reward_ad_description".localized
        case .category:
            return "reward_category_ad_description".localized
        }
    }

    private var rewardFeatureIcon: String {
        switch selectedRewardType {
        case .memo:
            return "play.rectangle.fill"
        case .category:
            return "folder.badge.plus"
        }
    }

    private var rewardFeatureColor: Color {
        switch selectedRewardType {
        case .memo:
            return .blue
        case .category:
            return .purple
        }
    }

    private var rewardFeatureTitle: String {
        switch selectedRewardType {
        case .memo:
            return "reward_feature_watch".localized
        case .category:
            return "reward_category_feature_watch".localized
        }
    }

    private var rewardFeatureDescription: String {
        switch selectedRewardType {
        case .memo:
            return String(format: "reward_feature_watch_desc".localized, RewardManager.memosPerReward)
        case .category:
            return String(format: "reward_category_feature_watch_desc".localized, RewardManager.categoriesPerReward)
        }
    }

    private func rewardFeatureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("reward_current_status".localized)
                    .font(.headline)
                Spacer()
            }

            // 報酬残数を表示（メモとカテゴリー両方）
            HStack(spacing: 12) {
                statusCard(
                    value: "\(rewardManager.rewardMemoCount)",
                    label: "reward_remaining_memos".localized,
                    color: rewardManager.hasRewardMemos ? .green : .gray,
                    isSelected: selectedRewardType == .memo
                )

                statusCard(
                    value: "\(rewardManager.rewardCategoryCount)",
                    label: "reward_remaining_categories".localized,
                    color: rewardManager.hasRewardCategories ? .purple : .gray,
                    isSelected: selectedRewardType == .category
                )
            }
        }
    }

    private func statusCard(value: String, label: String, color: Color, isSelected: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
    }

    private var watchAdButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: watchAd) {
                HStack(spacing: 8) {
                    if adManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "play.circle.fill")
                    }

                    Text(buttonText)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonBackgroundColor)
                .cornerRadius(12)
            }
            .disabled(!canWatchAd)

            // 広告準備中のメッセージ
            if !adManager.isRewardedAdReady && !adManager.isLoading {
                Text(disabledReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var proUpgradeSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)

                Text("reward_pro_suggestion".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            NavigationLink(destination: PurchaseView()) {
                HStack {
                    Text("reward_upgrade_to_pro".localized)
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Computed Properties

    private var buttonText: String {
        if adManager.isLoading {
            return "reward_loading_ad".localized
        } else if !adManager.isRewardedAdReady {
            return "reward_ad_not_ready".localized
        } else {
            switch selectedRewardType {
            case .memo:
                return String(format: "reward_watch_ad_button".localized, RewardManager.memosPerReward)
            case .category:
                return String(format: "reward_watch_ad_button_category".localized, RewardManager.categoriesPerReward)
            }
        }
    }

    private var buttonBackgroundColor: Color {
        if canWatchAd {
            switch selectedRewardType {
            case .memo:
                return .blue
            case .category:
                return .purple
            }
        } else {
            return .gray
        }
    }

    private var canWatchAd: Bool {
        return adManager.isRewardedAdReady && rewardManager.canWatchAd && !adManager.isLoading
    }

    private var disabledReason: String {
        if !adManager.isRewardedAdReady {
            return "reward_ad_loading".localized
        }
        return ""
    }

    // MARK: - Actions

    private func watchAd() {
        guard canWatchAd else { return }

        adManager.showRewardedAd { success in
            if success {
                switch selectedRewardType {
                case .memo:
                    rewardManager.grantMemoReward()
                    grantedCount = RewardManager.memosPerReward
                    successRewardType = .memo
                case .category:
                    rewardManager.grantCategoryReward()
                    grantedCount = RewardManager.categoriesPerReward
                    successRewardType = .category
                }
                showingSuccessAlert = true
            } else if adManager.errorMessage != nil {
                showingErrorAlert = true
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Compact Reward Button

/// メモ制限に達した時に表示するコンパクトな広告ボタン
struct CompactRewardAdButton: View {
    @ObservedObject private var rewardManager = RewardManager.shared
    @ObservedObject private var adManager = AdMobManager.shared

    @State private var showingRewardView = false

    var body: some View {
        Button(action: {
            showingRewardView = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("reward_compact_title".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(format: "reward_compact_subtitle".localized, RewardManager.memosPerReward))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingRewardView) {
            RewardAdView()
        }
    }
}

// MARK: - Reward Status Badge

/// 報酬メモの残数を表示するバッジ
struct RewardStatusBadge: View {
    @ObservedObject private var rewardManager = RewardManager.shared

    var body: some View {
        if rewardManager.hasRewardMemos {
            HStack(spacing: 4) {
                Image(systemName: "gift.fill")
                    .font(.caption2)

                Text("+\(rewardManager.rewardMemoCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange)
            .cornerRadius(10)
        }
    }
}

// MARK: - Preview

#Preview {
    RewardAdView()
}

#Preview("Compact Button") {
    VStack {
        CompactRewardAdButton()
            .padding()
    }
}
