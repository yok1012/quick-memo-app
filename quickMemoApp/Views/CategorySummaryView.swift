import SwiftUI

/// カテゴリー要約ビュー（カテゴリー内のメモを分析・要約）
struct CategorySummaryView: View {
    let category: Category
    let memos: [QuickMemo]
    @StateObject private var aiManager = AIManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var summaryResult: CategorySummaryResult?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                if isProcessing {
                    // 処理中
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()

                        Text("ai_analyzing_category".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(String(format: "ai_analyzing_count".localized, memos.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if let result = summaryResult {
                    // 要約結果表示
                    VStack(alignment: .leading, spacing: 24) {
                        // カテゴリー情報
                        categoryHeaderView

                        // 全体の要約
                        summarySection(result: result)

                        // 要点
                        keyPointsSection(result: result)

                        // トレンド（オプション）
                        if let trends = result.trends, !trends.isEmpty {
                            trendsSection(trends: trends)
                        }

                        // 統計情報
                        statisticsSection(result: result)

                        Spacer()
                    }
                    .padding()
                } else {
                    // 初期状態
                    VStack(spacing: 24) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                            .padding(.top, 60)

                        VStack(spacing: 12) {
                            Text("ai_category_summary".localized)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("\(category.name)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "ai_summary_description".localized, memos.count))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if memos.count < 3 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("ai_few_memos_warning".localized)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }

                        Button(action: generateSummary) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("ai_generate_summary".localized)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // 使用統計
                        usageStatsView
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("ai_category_summary".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) {
                        dismiss()
                    }
                }

                if summaryResult != nil {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: exportText()) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .alert("ai_error".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - View Components

    private var categoryHeaderView: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.title)
                .foregroundColor(Color(hex: category.color))

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(format: "ai_memo_count".localized, memos.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func summarySection(result: CategorySummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text("ai_overall_summary".localized)
                    .font(.headline)
            }

            Text(result.summary)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    private func keyPointsSection(result: CategorySummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.green)
                Text("ai_key_points".localized)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.keyPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .frame(width: 24)

                        Text(point)
                            .font(.body)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func trendsSection(trends: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                Text("ai_trends".localized)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(trends, id: \.self) { trend in
                    HStack {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(trend)
                            .font(.body)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func statisticsSection(result: CategorySummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.purple)
                Text("ai_statistics".localized)
                    .font(.headline)
            }

            VStack(spacing: 8) {
                statisticRow(label: "ai_analyzed_memos".localized, value: String(format: "ai_count_items".localized, result.totalMemos))
                statisticRow(label: "ai_key_point_count".localized, value: String(format: "ai_count_items".localized, result.keyPoints.count))
                if let trends = result.trends {
                    statisticRow(label: "ai_trend_count".localized, value: String(format: "ai_count_items".localized, trends.count))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func statisticRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var usageStatsView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "ai_monthly_usage".localized, aiManager.usageStats.totalRequests, aiManager.usageStats.monthlyLimit))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "ai_remaining".localized, aiManager.usageStats.remainingRequests))
                    .font(.caption)
                    .foregroundColor(aiManager.usageStats.isQuotaExceeded ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func generateSummary() {
        isProcessing = true

        Task {
            do {
                let result = try await aiManager.summarizeCategory(memos: memos, categoryName: category.name)

                await MainActor.run {
                    summaryResult = result
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func exportText() -> String {
        guard let result = summaryResult else { return "" }

        var text = """
        【\(String(format: "ai_category_summary_title".localized, category.name))】

        ■ \("ai_overall_summary".localized)
        \(result.summary)

        ■ \("ai_key_points".localized)
        """

        for (index, point) in result.keyPoints.enumerated() {
            text += "\n\(index + 1). \(point)"
        }

        if let trends = result.trends, !trends.isEmpty {
            text += "\n\n■ \("ai_trends".localized)"
            for trend in trends {
                text += "\n• \(trend)"
            }
        }

        text += """


        \("ai_analyzed_memos".localized): \(String(format: "ai_count_items".localized, result.totalMemos))
        \("ai_generation_date".localized): \(Date().formatted(date: .long, time: .shortened))
        """

        return text
    }
}

#Preview {
    CategorySummaryView(
        category: Category(
            id: UUID(),
            name: "仕事",
            icon: "briefcase.fill",
            color: "#007AFF",
            order: 0,
            defaultTags: []
        ),
        memos: [
            QuickMemo(
                content: "会議の議事録",
                primaryCategory: "仕事"
            ),
            QuickMemo(
                content: "プロジェクト進捗",
                primaryCategory: "仕事"
            )
        ]
    )
}
