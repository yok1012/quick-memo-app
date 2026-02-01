import SwiftUI

/// AI機能ごとのモデル選択ビュー
struct AIModelSelectionView: View {
    @StateObject private var aiManager = AIManager.shared
    @Environment(\.dismiss) private var dismiss

    let feature: AIFeature
    @State private var selectedProvider: AIProvider
    @State private var selectedModelId: String

    enum AIFeature: String, Identifiable {
        case tagExtraction = "tag_extraction"
        case memoArrange = "memo_arrange"
        case categorySummary = "category_summary"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .tagExtraction: return "ai_tag_extraction".localized
            case .memoArrange: return "ai_memo_arrange".localized
            case .categorySummary: return "ai_category_summary".localized
            }
        }
    }

    init(feature: AIFeature) {
        self.feature = feature

        let manager = AIManager.shared
        let selection: AIModelSelection

        switch feature {
        case .tagExtraction:
            selection = manager.modelPreferences.tagExtraction
        case .memoArrange:
            selection = manager.modelPreferences.memoArrange
        case .categorySummary:
            selection = manager.modelPreferences.categorySummary
        }

        _selectedProvider = State(initialValue: selection.provider)
        _selectedModelId = State(initialValue: selection.modelId)
    }

    var body: some View {
        NavigationView {
            Form {
                // プロバイダー選択
                Section("ai_provider".localized) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Button(action: {
                            selectedProvider = provider
                            // デフォルトモデルを選択
                            if let firstModel = provider.availableModels.first {
                                selectedModelId = firstModel.id
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(String(format: "ai_model_count".localized, provider.availableModels.count))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(!aiManager.hasAPIKey(for: getKeychainProvider(provider)))
                    }
                }

                // モデル選択
                Section("ai_model_selection".localized) {
                    ForEach(selectedProvider.availableModels) { model in
                        Button(action: {
                            selectedModelId = model.id
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(model.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if selectedModelId == model.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }

                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text("ai_input_label".localized + ": ")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    +
                                    Text(String(format: "$%.2f", model.inputCost))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)

                                    Text(" / " + "ai_output_label".localized + ": ")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    +
                                    Text(String(format: "$%.2f", model.outputCost))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)

                                    Text(" " + "ai_per_1m_tokens".localized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // APIキー設定案内
                Section {
                    ForEach(AIProvider.allCases.filter { !aiManager.hasAPIKey(for: getKeychainProvider($0)) }, id: \.self) { provider in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(String(format: "ai_api_key_not_set".localized, provider.displayName))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(feature.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveSelection()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getKeychainProvider(_ provider: AIProvider) -> KeychainManager.APIProvider {
        switch provider {
        case .gemini: return .gemini
        case .claude: return .claude
        case .chatgpt: return .openai
        }
    }

    private func saveSelection() {
        aiManager.updateModelPreference(
            for: feature.rawValue,
            provider: selectedProvider,
            modelId: selectedModelId
        )
    }
}

#Preview {
    AIModelSelectionView(feature: .tagExtraction)
}
