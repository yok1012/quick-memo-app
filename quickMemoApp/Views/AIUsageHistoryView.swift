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
            .navigationTitle("ai_usage_history".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: exportToCSV) {
                            Label("ai_export_csv".localized, systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive, action: clearHistory) {
                            Label("ai_clear_history".localized, systemImage: "trash")
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
            Text("ai_all_time_stats".localized)
                .font(.headline)

            HStack(spacing: 20) {
                StatCard(
                    title: "ai_total_requests".localized,
                    value: "\(aiManager.usageHistory.logs.count)",
                    icon: "number",
                    color: .blue
                )

                StatCard(
                    title: "ai_total_cost".localized,
                    value: String(format: "$%.4f", totalCost),
                    icon: "dollarsign.circle",
                    color: .green
                )
            }
        }
    }

    private var currentMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ai_this_month_stats".localized)
                .font(.headline)

            let monthLogs = aiManager.usageHistory.currentMonthLogs()
            let monthCost = monthLogs.reduce(0.0) { $0 + $1.estimatedCost }
            let monthTokens = monthLogs.reduce(0) { $0 + $1.totalTokens }

            HStack(spacing: 20) {
                StatCard(
                    title: "ai_request_count".localized,
                    value: "\(monthLogs.count)",
                    icon: "calendar",
                    color: .purple
                )

                StatCard(
                    title: "ai_token_count".localized,
                    value: formatNumber(monthTokens),
                    icon: "text.alignleft",
                    color: .orange
                )
            }

            StatCard(
                title: "ai_cost".localized,
                value: String(format: "$%.4f", monthCost),
                icon: "yensign.circle",
                color: .green
            )
        }
    }

    private var requestTypeStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ai_stats_by_feature".localized)
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
            Text("ai_stats_by_provider".localized)
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
            Text("ai_recent_history".localized)
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
        case "tag_extraction": return "ai_tag_extraction".localized
        case "memo_arrange": return "ai_memo_arrange".localized
        case "category_summary": return "ai_category_summary".localized
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
                Text(String(format: "ai_times_count".localized, count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(String(format: "ai_tokens_label".localized, formatNumber(tokens)))
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
                Text(String(format: "ai_times_count".localized, count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(String(format: "ai_tokens_label".localized, formatNumber(tokens)))
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
                Text(String(format: "ai_error_message".localized, errorMessage))
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
