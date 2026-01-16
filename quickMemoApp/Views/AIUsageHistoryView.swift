import SwiftUI

/// AI使用履歴の詳細表示ビュー
struct AIUsageHistoryView: View {
    @StateObject private var aiManager = AIManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSheet = false
    @State private var csvContent = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 概要統計
                    summarySection

                    // 今月の統計
                    currentMonthSection

                    // リクエストタイプ別統計
                    requestTypeStatsSection

                    // プロバイダー別統計
                    providerStatsSection

                    // 履歴リスト
                    historyListSection
                }
                .padding()
            }
            .navigationTitle("AI使用履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: exportToCSV) {
                            Label("CSVでエクスポート", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive, action: clearHistory) {
                            Label("履歴をクリア", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                AIUsageShareSheet(activityItems: [csvContent])
            }
        }
    }

    // MARK: - View Components

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全期間の統計")
                .font(.headline)

            HStack(spacing: 20) {
                StatCard(
                    title: "総リクエスト数",
                    value: "\(aiManager.usageHistory.logs.count)",
                    icon: "number",
                    color: .blue
                )

                StatCard(
                    title: "総コスト",
                    value: String(format: "$%.4f", totalCost),
                    icon: "dollarsign.circle",
                    color: .green
                )
            }
        }
    }

    private var currentMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今月の統計")
                .font(.headline)

            let monthLogs = aiManager.usageHistory.currentMonthLogs()
            let monthCost = monthLogs.reduce(0.0) { $0 + $1.estimatedCost }
            let monthTokens = monthLogs.reduce(0) { $0 + $1.totalTokens }

            HStack(spacing: 20) {
                StatCard(
                    title: "リクエスト数",
                    value: "\(monthLogs.count)",
                    icon: "calendar",
                    color: .purple
                )

                StatCard(
                    title: "トークン数",
                    value: formatNumber(monthTokens),
                    icon: "text.alignleft",
                    color: .orange
                )
            }

            StatCard(
                title: "コスト",
                value: String(format: "$%.4f", monthCost),
                icon: "yensign.circle",
                color: .green
            )
        }
    }

    private var requestTypeStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("機能別統計")
                .font(.headline)

            let stats = aiManager.usageHistory.statsByRequestType()

            ForEach(Array(stats.keys.sorted()), id: \.self) { type in
                if let stat = stats[type] {
                    RequestTypeStatRow(
                        type: type,
                        count: stat.count,
                        cost: stat.totalCost,
                        tokens: stat.totalTokens
                    )
                }
            }
        }
    }

    private var providerStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プロバイダー別統計")
                .font(.headline)

            let stats = aiManager.usageHistory.statsByProvider()

            ForEach(Array(stats.keys.sorted()), id: \.self) { provider in
                if let stat = stats[provider] {
                    ProviderStatRow(
                        provider: provider,
                        count: stat.count,
                        cost: stat.totalCost,
                        tokens: stat.totalTokens
                    )
                }
            }
        }
    }

    private var historyListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("直近の履歴 (最新50件)")
                .font(.headline)

            ForEach(Array(aiManager.usageHistory.logs.suffix(50).reversed())) { log in
                LogEntryRow(log: log)
            }
        }
    }

    // MARK: - Helper Properties

    private var totalCost: Double {
        aiManager.usageHistory.logs.reduce(0.0) { $0 + $1.estimatedCost }
    }

    // MARK: - Actions

    private func exportToCSV() {
        csvContent = aiManager.exportUsageHistoryCSV()
        showingExportSheet = true
    }

    private func clearHistory() {
        aiManager.clearUsageHistory()
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RequestTypeStatRow: View {
    let type: String
    let count: Int
    let cost: Double
    let tokens: Int

    var displayType: String {
        switch type {
        case "tag_extraction": return "タグ抽出"
        case "memo_arrange": return "メモアレンジ"
        case "category_summary": return "カテゴリー要約"
        default: return type
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(count)回")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("トークン: \(formatNumber(tokens))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "$%.6f", cost))
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct ProviderStatRow: View {
    let provider: String
    let count: Int
    let cost: Double
    let tokens: Int

    var displayProvider: String {
        switch provider {
        case "gemini": return "Gemini"
        case "claude": return "Claude"
        default: return provider
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayProvider)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(count)回")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("トークン: \(formatNumber(tokens))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "$%.6f", cost))
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct LogEntryRow: View {
    let log: AIUsageLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(log.success ? .green : .red)
                    .font(.caption)

                Text(log.displayRequestType)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Label(log.displayProvider, systemImage: "server.rack")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("in: \(log.inputTokens) / out: \(log.outputTokens)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "$%.6f", log.estimatedCost))
                    .font(.caption)
                    .foregroundColor(.green)
            }

            if let errorMessage = log.errorMessage {
                Text("エラー: \(errorMessage)")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// ShareSheet for CSV export
struct AIUsageShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AIUsageHistoryView()
}
