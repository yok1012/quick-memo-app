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

                        Text("AIがカテゴリーを分析しています...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(memos.count)件のメモを解析中")
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
                            Text("カテゴリー要約")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("\(category.name)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        Text("\(memos.count)件のメモを分析して、要約と要点を抽出します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if memos.count < 3 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("メモが3件未満です。より正確な分析には、もっとメモを追加してください。")
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
                                Text("要約を生成")
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
            .navigationTitle("カテゴリー要約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
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
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
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

                Text("\(memos.count)件のメモ")
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
                Text("全体の要約")
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
                Text("主な要点")
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
                Text("トレンド")
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
                Text("統計情報")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                statisticRow(label: "分析メモ数", value: "\(result.totalMemos)件")
                statisticRow(label: "要点数", value: "\(result.keyPoints.count)件")
                if let trends = result.trends {
                    statisticRow(label: "トレンド数", value: "\(trends.count)件")
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

                Text("今月の使用: \(aiManager.usageStats.totalRequests)/\(aiManager.usageStats.monthlyLimit)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("残り: \(aiManager.usageStats.remainingRequests)")
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
        【\(category.name)カテゴリー要約】

        ■ 全体の要約
        \(result.summary)

        ■ 主な要点
        """

        for (index, point) in result.keyPoints.enumerated() {
            text += "\n\(index + 1). \(point)"
        }

        if let trends = result.trends, !trends.isEmpty {
            text += "\n\n■ トレンド"
            for trend in trends {
                text += "\n• \(trend)"
            }
        }

        text += """


        分析メモ数: \(result.totalMemos)件
        生成日時: \(Date().formatted(date: .long, time: .shortened))
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
