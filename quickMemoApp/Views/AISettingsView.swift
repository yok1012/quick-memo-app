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

    // Pro版AI機能の使用量
    @State private var proAIUsage: ProAIUsageResponse?
    @State private var isLoadingUsage = false

    var body: some View {
        List {
            // Pro Version AI Features Section
            Section {
                if PurchaseManager.shared.isProVersion {
                    // Pro版ユーザー向け表示
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("APIキー不要でAI機能を利用できます")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        if isLoadingUsage {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if let usage = proAIUsage {
                            VStack(alignment: .leading, spacing: 8) {
                                // 使用量プログレスバー
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("今月の使用回数")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(usage.count) / \(usage.limit)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }

                                    ProgressView(value: Double(usage.count), total: Double(usage.limit))
                                        .tint(usage.remaining < 10 ? .red : .blue)
                                }

                                // 残り使用回数
                                HStack {
                                    Text("残り")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(usage.remaining) 回")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(usage.remaining < 10 ? .red : .primary)
                                }

                                // リセット日
                                Text("リセット日: \(usage.resetDate)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        } else {
                            Button(action: {
                                loadProAIUsage()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("使用量を読み込む")
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    // 無料版ユーザー向け表示
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pro版にアップグレードすると、APIキー不要でAI機能を利用できます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        NavigationLink(destination: PurchaseView()) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Pro版にアップグレード")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Pro版 AI機能")
            } footer: {
                if PurchaseManager.shared.isProVersion {
                    Text("Pro版ユーザーは月間100回まで、開発者提供のAI機能を無料で利用できます。超過後は個人のAPIキーが必要になります。")
                        .font(.caption)
                } else {
                    Text("Pro版にアップグレードすると、自分のAPIキーを登録せずにAI機能を利用できます（月間100回まで）。")
                        .font(.caption)
                }
            }

            // API Key Management Section
            Section {
                // Gemini API
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gemini API")
                            .font(.headline)
                        Text("ai_used_for_tag_extraction".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if aiManager.hasAPIKey(for: .gemini) {
                        Button("delete".localized) {
                            deleteGeminiKey()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("ai_api_key_input".localized) {
                            showingGeminiInput = true
                        }
                    }
                }

                // Claude API
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Claude API")
                            .font(.headline)
                        Text("ai_used_for_arrange_summary".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if aiManager.hasAPIKey(for: .claude) {
                        Button("delete".localized) {
                            deleteClaudeKey()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("ai_api_key_input".localized) {
                            showingClaudeInput = true
                        }
                    }
                }

                // ChatGPT API
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ChatGPT API")
                            .font(.headline)
                        Text("ai_used_for_all_features".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if aiManager.hasAPIKey(for: .openai) {
                        Button("delete".localized) {
                            deleteChatGPTKey()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("ai_api_key_input".localized) {
                            showingChatGPTInput = true
                        }
                    }
                }
            } header: {
                Text("ai_api_key_management".localized)
            } footer: {
                Text("ai_api_key_footer".localized)
                    .font(.caption)
            }

            // Model Selection Section
            Section("ai_model_by_feature".localized) {
                // タグ抽出
                Button(action: {
                    showingModelSelection = .tagExtraction
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ai_tag_extraction".localized)
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
                            Text("ai_memo_arrange".localized)
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
                            Text("ai_category_summary".localized)
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
            Section("ai_usage_stats".localized) {
                HStack {
                    Text("ai_monthly_requests".localized)
                    Spacer()
                    Text("\(aiManager.usageStats.totalRequests)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("ai_remaining_requests".localized)
                    Spacer()
                    Text("\(aiManager.usageStats.remainingRequests)")
                        .foregroundColor(aiManager.usageStats.isQuotaExceeded ? .red : .green)
                }

                HStack {
                    Text("ai_monthly_limit".localized)
                    Spacer()
                    Text("\(aiManager.usageStats.monthlyLimit)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("ai_total_tokens".localized)
                    Spacer()
                    Text("\(aiManager.usageStats.totalTokens)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("ai_estimated_cost".localized)
                    Spacer()
                    Text(String(format: "$%.4f", aiManager.usageStats.totalCost))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("ai_last_reset_date".localized)
                    Spacer()
                    Text(formatDate(aiManager.usageStats.lastResetDate))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            // Usage Breakdown Section
            if !aiManager.usageStats.requestsByType.isEmpty {
                Section("ai_usage_by_type".localized) {
                    ForEach(Array(aiManager.usageStats.requestsByType.keys.sorted()), id: \.self) { type in
                        HStack {
                            Text(localizedTypeName(type))
                            Spacer()
                            Text(String(format: "ai_times_count".localized, aiManager.usageStats.requestsByType[type] ?? 0))
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
                            Text("ai_usage_history_detail".localized)
                                .font(.subheadline)
                            Text("ai_usage_history_footer".localized)
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
                    Label("ai_reset_usage_stats".localized, systemImage: "trash")
                }
            }

            // Help Section
            Section("ai_help".localized) {
                Link(destination: URL(string: "https://ai.google.dev/")!) {
                    HStack {
                        Text("ai_get_gemini_key".localized)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }

                Link(destination: URL(string: "https://console.anthropic.com/")!) {
                    HStack {
                        Text("ai_get_claude_key".localized)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("ai_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Pro版ユーザーの場合、使用量を自動読み込み
            if PurchaseManager.shared.isProVersion {
                loadProAIUsage()
            }
        }
        .sheet(isPresented: $showingGeminiInput) {
            APIKeyInputView(
                title: "ai_gemini_api_key".localized,
                placeholder: "AIza...",
                apiKey: $geminiKey,
                onSave: {
                    saveGeminiKey()
                }
            )
        }
        .sheet(isPresented: $showingClaudeInput) {
            APIKeyInputView(
                title: "ai_claude_api_key".localized,
                placeholder: "sk-ant-...",
                apiKey: $claudeKey,
                onSave: {
                    saveClaudeKey()
                }
            )
        }
        .sheet(isPresented: $showingChatGPTInput) {
            APIKeyInputView(
                title: "ai_chatgpt_api_key".localized,
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
        .alert("ai_settings".localized, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Helper Methods

    private func saveGeminiKey() {
        do {
            try aiManager.setAPIKey(geminiKey, for: .gemini)
            alertMessage = String(format: "ai_api_key_saved".localized, "Gemini")
            showAlert = true
            geminiKey = ""
            showingGeminiInput = false
        } catch {
            alertMessage = String(format: "ai_error_message".localized, error.localizedDescription)
            showAlert = true
        }
    }

    private func deleteGeminiKey() {
        do {
            try aiManager.deleteAPIKey(for: .gemini)
            alertMessage = String(format: "ai_api_key_deleted".localized, "Gemini")
            showAlert = true
        } catch {
            alertMessage = String(format: "ai_error_message".localized, error.localizedDescription)
            showAlert = true
        }
    }

    private func saveClaudeKey() {
        do {
            try aiManager.setAPIKey(claudeKey, for: .claude)
            alertMessage = String(format: "ai_api_key_saved".localized, "Claude")
            showAlert = true
            claudeKey = ""
            showingClaudeInput = false
        } catch {
            alertMessage = String(format: "ai_error_message".localized, error.localizedDescription)
            showAlert = true
        }
    }

    private func deleteClaudeKey() {
        do {
            try aiManager.deleteAPIKey(for: .claude)
            alertMessage = String(format: "ai_api_key_deleted".localized, "Claude")
            showAlert = true
        } catch {
            alertMessage = String(format: "ai_error_message".localized, error.localizedDescription)
            showAlert = true
        }
    }

    private func saveChatGPTKey() {
        do {
            try aiManager.setAPIKey(chatGPTKey, for: .openai)
            alertMessage = String(format: "ai_api_key_saved".localized, "ChatGPT")
            showAlert = true
            chatGPTKey = ""
            showingChatGPTInput = false
        } catch {
            alertMessage = String(format: "ai_error_message".localized, error.localizedDescription)
            showAlert = true
        }
    }

    private func deleteChatGPTKey() {
        do {
            try aiManager.deleteAPIKey(for: .openai)
            alertMessage = String(format: "ai_api_key_deleted".localized, "ChatGPT")
            showAlert = true
        } catch {
            alertMessage = String(format: "ai_error_message".localized, error.localizedDescription)
            showAlert = true
        }
    }

    private func resetStats() {
        aiManager.resetUsageStats()
        alertMessage = "ai_stats_reset".localized
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
            return "ai_tag_extraction".localized
        case "memo_arrange":
            return "ai_memo_arrange".localized
        case "category_summary":
            return "ai_category_summary".localized
        default:
            return type
        }
    }

    // MARK: - Pro AI Usage

    /// Pro版AI使用量を読み込む
    private func loadProAIUsage() {
        guard PurchaseManager.shared.isProVersion else { return }

        isLoadingUsage = true

        Task {
            do {
                let usage = try await aiManager.getProAIUsage()
                await MainActor.run {
                    self.proAIUsage = usage
                    self.isLoadingUsage = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingUsage = false
                    self.alertMessage = "使用量の取得に失敗しました: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
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
                    Text("ai_api_key_input".localized)
                } footer: {
                    Text("ai_api_key_save_secure".localized)
                }

                Section {
                    Button("save".localized) {
                        onSave()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
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
