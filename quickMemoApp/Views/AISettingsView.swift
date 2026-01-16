import SwiftUI

struct AISettingsView: View {
    @StateObject private var aiManager = AIManager.shared
    @State private var geminiKey: String = ""
    @State private var claudeKey: String = ""
    @State private var chatGPTKey: String = ""
    @State private var showingGeminiInput = false
    @State private var showingClaudeInput = false
    @State private var showingChatGPTInput = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingModelSelection: AIModelSelectionView.AIFeature? = nil

    var body: some View {
        List {
            // API Key Management Section
            Section {
                // Gemini API
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gemini API")
                            .font(.headline)
                        Text("タグ抽出に使用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if aiManager.hasAPIKey(for: .gemini) {
                        Button("削除") {
                            deleteGeminiKey()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("設定") {
                            showingGeminiInput = true
                        }
                    }
                }

                // Claude API
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Claude API")
                            .font(.headline)
                        Text("メモアレンジ・要約に使用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if aiManager.hasAPIKey(for: .claude) {
                        Button("削除") {
                            deleteClaudeKey()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("設定") {
                            showingClaudeInput = true
                        }
                    }
                }

                // ChatGPT API
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ChatGPT API")
                            .font(.headline)
                        Text("全機能に使用可能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if aiManager.hasAPIKey(for: .openai) {
                        Button("削除") {
                            deleteChatGPTKey()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("設定") {
                            showingChatGPTInput = true
                        }
                    }
                }
            } header: {
                Text("APIキー管理")
            } footer: {
                Text("APIキーはお客様のデバイスに安全に保存されます。料金は各APIプロバイダーに直接お支払いください。")
                    .font(.caption)
            }

            // Model Selection Section
            Section("機能別モデル設定") {
                // タグ抽出
                Button(action: {
                    showingModelSelection = .tagExtraction
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("タグ抽出")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            let selection = aiManager.modelPreferences.tagExtraction
                            let model = selection.getModel()

                            Text("\(selection.provider.displayName) - \(model?.name ?? selection.modelId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // メモアレンジ
                Button(action: {
                    showingModelSelection = .memoArrange
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("メモアレンジ")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            let selection = aiManager.modelPreferences.memoArrange
                            let model = selection.getModel()

                            Text("\(selection.provider.displayName) - \(model?.name ?? selection.modelId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // カテゴリー要約
                Button(action: {
                    showingModelSelection = .categorySummary
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("カテゴリー要約")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            let selection = aiManager.modelPreferences.categorySummary
                            let model = selection.getModel()

                            Text("\(selection.provider.displayName) - \(model?.name ?? selection.modelId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Usage Statistics Section
            Section("使用統計") {
                HStack {
                    Text("今月のリクエスト数")
                    Spacer()
                    Text("\(aiManager.usageStats.totalRequests)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("残りリクエスト数")
                    Spacer()
                    Text("\(aiManager.usageStats.remainingRequests)")
                        .foregroundColor(aiManager.usageStats.isQuotaExceeded ? .red : .green)
                }

                HStack {
                    Text("月間制限")
                    Spacer()
                    Text("\(aiManager.usageStats.monthlyLimit)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("累計トークン数")
                    Spacer()
                    Text("\(aiManager.usageStats.totalTokens)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("推定コスト")
                    Spacer()
                    Text(String(format: "$%.4f", aiManager.usageStats.totalCost))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("最終リセット日")
                    Spacer()
                    Text(formatDate(aiManager.usageStats.lastResetDate))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            // Usage Breakdown Section
            if !aiManager.usageStats.requestsByType.isEmpty {
                Section("機能別使用状況") {
                    ForEach(Array(aiManager.usageStats.requestsByType.keys.sorted()), id: \.self) { type in
                        HStack {
                            Text(localizedTypeName(type))
                            Spacer()
                            Text("\(aiManager.usageStats.requestsByType[type] ?? 0)回")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Usage History Section
            Section {
                NavigationLink(destination: AIUsageHistoryView()) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("詳細な使用履歴")
                                .font(.subheadline)
                            Text("すべてのリクエストログを確認・エクスポート")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Actions Section
            Section {
                Button(role: .destructive) {
                    resetStats()
                } label: {
                    Label("使用統計をリセット", systemImage: "trash")
                }
            }

            // Help Section
            Section("ヘルプ") {
                Link(destination: URL(string: "https://ai.google.dev/")!) {
                    HStack {
                        Text("Gemini APIキーを取得")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }

                Link(destination: URL(string: "https://console.anthropic.com/")!) {
                    HStack {
                        Text("Claude APIキーを取得")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("AI機能設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingGeminiInput) {
            APIKeyInputView(
                title: "Gemini APIキー",
                placeholder: "AIza...",
                apiKey: $geminiKey,
                onSave: {
                    saveGeminiKey()
                }
            )
        }
        .sheet(isPresented: $showingClaudeInput) {
            APIKeyInputView(
                title: "Claude APIキー",
                placeholder: "sk-ant-...",
                apiKey: $claudeKey,
                onSave: {
                    saveClaudeKey()
                }
            )
        }
        .sheet(isPresented: $showingChatGPTInput) {
            APIKeyInputView(
                title: "ChatGPT APIキー",
                placeholder: "sk-...",
                apiKey: $chatGPTKey,
                onSave: {
                    saveChatGPTKey()
                }
            )
        }
        .sheet(item: $showingModelSelection) { feature in
            AIModelSelectionView(feature: feature)
        }
        .alert("AI設定", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Helper Methods

    private func saveGeminiKey() {
        do {
            try aiManager.setAPIKey(geminiKey, for: .gemini)
            alertMessage = "Gemini APIキーを保存しました"
            showAlert = true
            geminiKey = ""
            showingGeminiInput = false
        } catch {
            alertMessage = "エラー: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func deleteGeminiKey() {
        do {
            try aiManager.deleteAPIKey(for: .gemini)
            alertMessage = "Gemini APIキーを削除しました"
            showAlert = true
        } catch {
            alertMessage = "エラー: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func saveClaudeKey() {
        do {
            try aiManager.setAPIKey(claudeKey, for: .claude)
            alertMessage = "Claude APIキーを保存しました"
            showAlert = true
            claudeKey = ""
            showingClaudeInput = false
        } catch {
            alertMessage = "エラー: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func deleteClaudeKey() {
        do {
            try aiManager.deleteAPIKey(for: .claude)
            alertMessage = "Claude APIキーを削除しました"
            showAlert = true
        } catch {
            alertMessage = "エラー: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func saveChatGPTKey() {
        do {
            try aiManager.setAPIKey(chatGPTKey, for: .openai)
            alertMessage = "ChatGPT APIキーを保存しました"
            showAlert = true
            chatGPTKey = ""
            showingChatGPTInput = false
        } catch {
            alertMessage = "エラー: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func deleteChatGPTKey() {
        do {
            try aiManager.deleteAPIKey(for: .openai)
            alertMessage = "ChatGPT APIキーを削除しました"
            showAlert = true
        } catch {
            alertMessage = "エラー: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func resetStats() {
        aiManager.resetUsageStats()
        alertMessage = "使用統計をリセットしました"
        showAlert = true
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func localizedTypeName(_ type: String) -> String {
        switch type {
        case "tag_extraction":
            return "タグ抽出"
        case "memo_arrange":
            return "メモアレンジ"
        case "category_summary":
            return "カテゴリー要約"
        default:
            return type
        }
    }
}

// MARK: - API Key Input View

struct APIKeyInputView: View {
    let title: String
    let placeholder: String
    @Binding var apiKey: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField(placeholder, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("APIキーを入力")
                } footer: {
                    Text("APIキーは安全にKeychainに保存されます。第三者に共有しないでください。")
                }

                Section {
                    Button("保存") {
                        onSave()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AISettingsView()
    }
}
