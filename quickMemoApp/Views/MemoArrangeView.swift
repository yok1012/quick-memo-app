import SwiftUI

// MARK: - カスタムプロンプトモデル
struct CustomPrompt: Codable, Identifiable {
    var id = UUID()
    var name: String
    var prompt: String
    var icon: String

    static let defaultIcon = "star.fill"
    static let availableIcons = ["star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "sparkles"]
}

// MARK: - カスタムプロンプト管理
class CustomPromptManager: ObservableObject {
    static let shared = CustomPromptManager()

    @Published var customPrompts: [CustomPrompt] = []
    private let storageKey = "customArrangePrompts"
    private let maxPrompts = 3

    init() {
        loadPrompts()
    }

    func loadPrompts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let prompts = try? JSONDecoder().decode([CustomPrompt].self, from: data) {
            customPrompts = prompts
        }
    }

    func savePrompts() {
        if let data = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addPrompt(_ prompt: CustomPrompt) -> Bool {
        guard customPrompts.count < maxPrompts else { return false }
        customPrompts.append(prompt)
        savePrompts()
        return true
    }

    func updatePrompt(_ prompt: CustomPrompt) {
        if let index = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
            customPrompts[index] = prompt
            savePrompts()
        }
    }

    func deletePrompt(_ prompt: CustomPrompt) {
        customPrompts.removeAll { $0.id == prompt.id }
        savePrompts()
    }

    var canAddMore: Bool {
        customPrompts.count < maxPrompts
    }
}

/// メモアレンジビュー（AIによるメモ編集）
struct MemoArrangeView: View {
    @Binding var memoContent: String
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var promptManager = CustomPromptManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: String = ""
    @State private var selectedCustomPromptId: UUID?
    @State private var customInstruction: String = ""
    @State private var arrangedContent: String = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showResult = false
    @State private var showAddPrompt = false
    @State private var showEditPrompt = false
    @State private var showPromptHints = false
    @State private var editingPrompt: CustomPrompt?
    @State private var showClaudeCodeExport = false

    var body: some View {
        NavigationView {
            List {
                // 元のメモ
                Section("ai_original_memo".localized) {
                    Text(memoContent)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                }

                // Claude Code出力セクション
                Section {
                    Button(action: {
                        showClaudeCodeExport = true
                    }) {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ai_claude_code_export".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text("ai_claude_code_export_desc".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("ai_external_integration".localized)
                }

                // プリセット選択
                Section {
                    ForEach(presets, id: \.key) { preset in
                        Button(action: {
                            selectedPreset = preset.key
                            selectedCustomPromptId = nil
                            customInstruction = ""
                        }) {
                            HStack {
                                Image(systemName: preset.icon)
                                    .foregroundColor(preset.color)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text(preset.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedPreset == preset.key {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                } header: {
                    Text("ai_presets".localized)
                } footer: {
                    Text("ai_presets_footer".localized)
                        .font(.caption)
                }

                // カスタムプロンプトセクション
                Section {
                    // 保存済みカスタムプロンプト
                    ForEach(promptManager.customPrompts) { prompt in
                        Button(action: {
                            selectedCustomPromptId = prompt.id
                            selectedPreset = ""
                            customInstruction = ""
                        }) {
                            HStack {
                                Image(systemName: prompt.icon)
                                    .foregroundColor(.purple)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(prompt.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text(prompt.prompt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedCustomPromptId == prompt.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                promptManager.deletePrompt(prompt)
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }

                            Button {
                                editingPrompt = prompt
                                showEditPrompt = true
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }

                    // 新規追加ボタン
                    if promptManager.canAddMore {
                        Button(action: {
                            showAddPrompt = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)

                                Text("ai_add_custom_prompt".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)

                                Spacer()

                                Text("\(promptManager.customPrompts.count)/3")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // ヒント表示ボタン
                    Button(action: {
                        showPromptHints = true
                    }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 30)

                            Text("ai_prompt_hints".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("ai_custom_prompts".localized)
                } footer: {
                    Text("ai_custom_prompts_footer".localized)
                        .font(.caption)
                }

                // 一時的なカスタム指示
                Section {
                    TextEditor(text: $customInstruction)
                        .frame(minHeight: 80)
                        .onChange(of: customInstruction) { newValue in
                            if !newValue.isEmpty {
                                selectedPreset = ""
                                selectedCustomPromptId = nil
                            }
                        }
                } header: {
                    Text("ai_temporary_instruction".localized)
                } footer: {
                    Text("ai_temporary_instruction_footer".localized)
                        .font(.caption)
                }

                // アレンジボタン
                Section {
                    Button(action: arrangeMemo) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("ai_processing".localized)
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("ai_arrange_memo_button".localized)
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(canArrange ? Color.purple : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canArrange || isProcessing)
                    .listRowBackground(Color.clear)
                }

                // 使用統計
                Section {
                    HStack {
                        Text("ai_monthly_usage_simple".localized)
                        Spacer()
                        Text("\(aiManager.usageStats.totalRequests)/\(aiManager.usageStats.monthlyLimit)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("ai_remaining_count".localized)
                        Spacer()
                        Text("\(aiManager.usageStats.remainingRequests)")
                            .foregroundColor(aiManager.usageStats.isQuotaExceeded ? .red : .green)
                    }
                } header: {
                    Text("ai_usage_stats".localized)
                }
            }
            .navigationTitle("ai_memo_arrange".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("ai_error".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showResult) {
                ArrangedResultView(
                    originalContent: memoContent,
                    arrangedContent: arrangedContent,
                    onApply: {
                        memoContent = arrangedContent
                        dismiss()
                    },
                    onDismiss: {
                        showResult = false
                    }
                )
            }
            .sheet(isPresented: $showAddPrompt) {
                CustomPromptEditorView(
                    mode: .add,
                    onSave: { prompt in
                        _ = promptManager.addPrompt(prompt)
                    }
                )
            }
            .sheet(isPresented: $showEditPrompt) {
                if let prompt = editingPrompt {
                    CustomPromptEditorView(
                        mode: .edit(prompt),
                        onSave: { updatedPrompt in
                            promptManager.updatePrompt(updatedPrompt)
                        }
                    )
                }
            }
            .sheet(isPresented: $showPromptHints) {
                PromptHintsView()
            }
            .sheet(isPresented: $showClaudeCodeExport) {
                ClaudeCodeExportView(memoContent: memoContent)
            }
        }
    }

    private var canArrange: Bool {
        !selectedPreset.isEmpty || selectedCustomPromptId != nil || !customInstruction.isEmpty
    }

    private var presets: [(key: String, title: String, description: String, icon: String, color: Color)] {
        [
            ("summarize", "ai_preset_summarize".localized, "ai_preset_summarize_desc".localized, "text.alignleft", .blue),
            ("business", "ai_preset_business".localized, "ai_preset_business_desc".localized, "briefcase.fill", .orange),
            ("casual", "ai_preset_casual".localized, "ai_preset_casual_desc".localized, "message.fill", .green),
            ("expand", "ai_preset_expand".localized, "ai_preset_expand_desc".localized, "arrow.up.left.and.arrow.down.right", .purple),
            ("bullets", "ai_preset_bullets".localized, "ai_preset_bullets_desc".localized, "list.bullet", .indigo),
            ("translate_en", "ai_preset_translate_en".localized, "ai_preset_translate_en_desc".localized, "globe", .cyan),
            ("translate_ja", "ai_preset_translate_ja".localized, "ai_preset_translate_ja_desc".localized, "globe", .pink)
        ]
    }

    private func arrangeMemo() {
        isProcessing = true

        let instruction: String
        if !customInstruction.isEmpty {
            instruction = customInstruction
        } else if let promptId = selectedCustomPromptId,
                  let customPrompt = promptManager.customPrompts.first(where: { $0.id == promptId }) {
            instruction = customPrompt.prompt
        } else if let preset = AIManager.arrangePresets[selectedPreset] {
            instruction = preset
        } else {
            return
        }

        Task {
            do {
                let result = try await aiManager.arrangeMemo(content: memoContent, instruction: instruction)

                await MainActor.run {
                    arrangedContent = result
                    isProcessing = false
                    showResult = true
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
}

// MARK: - カスタムプロンプト編集ビュー
struct CustomPromptEditorView: View {
    enum Mode {
        case add
        case edit(CustomPrompt)
    }

    let mode: Mode
    let onSave: (CustomPrompt) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var selectedIcon: String = CustomPrompt.defaultIcon

    init(mode: Mode, onSave: @escaping (CustomPrompt) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let existingPrompt) = mode {
            _name = State(initialValue: existingPrompt.name)
            _prompt = State(initialValue: existingPrompt.prompt)
            _selectedIcon = State(initialValue: existingPrompt.icon)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("ai_prompt_name_placeholder".localized, text: $name)
                } header: {
                    Text("ai_name".localized)
                } footer: {
                    Text("ai_prompt_name_footer".localized)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(CustomPrompt.availableIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? .white : .purple)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(selectedIcon == icon ? Color.purple : Color(.systemGray5))
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("ai_icon".localized)
                }

                Section {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 150)
                } header: {
                    Text("ai_prompt_content".localized)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ai_hint_label".localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("ai_hint_1".localized)
                        Text("ai_hint_2".localized)
                        Text("ai_hint_3".localized)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle(mode.isAdd ? "ai_add_prompt".localized : "ai_edit_prompt".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        savePrompt()
                    }
                    .disabled(name.isEmpty || prompt.isEmpty)
                }
            }
        }
    }

    private func savePrompt() {
        var newPrompt: CustomPrompt
        if case .edit(let existing) = mode {
            newPrompt = existing
            newPrompt.name = name
            newPrompt.prompt = prompt
            newPrompt.icon = selectedIcon
        } else {
            newPrompt = CustomPrompt(name: name, prompt: prompt, icon: selectedIcon)
        }
        onSave(newPrompt)
        dismiss()
    }
}

extension CustomPromptEditorView.Mode {
    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
}

// MARK: - プロンプト作成ヒントビュー
struct PromptHintsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基本原則
                    VStack(alignment: .leading, spacing: 12) {
                        Label("ai_basic_principles".localized, systemImage: "1.circle.fill")
                            .font(.headline)
                            .foregroundColor(.blue)

                        Text("ai_prompt_elements".localized)
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 8) {
                            HintItem(icon: "target", text: "ai_element_purpose".localized)
                            HintItem(icon: "doc.text", text: "ai_element_format".localized)
                            HintItem(icon: "ruler", text: "ai_element_constraints".localized)
                            HintItem(icon: "person.fill", text: "ai_element_tone".localized)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 例1
                    VStack(alignment: .leading, spacing: 12) {
                        Label("ai_example_1_title".localized, systemImage: "doc.richtext")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text("ai_example_1_content".localized)
                            .font(.caption)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 例2
                    VStack(alignment: .leading, spacing: 12) {
                        Label("ai_example_2_title".localized, systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .foregroundColor(.pink)

                        Text("ai_example_2_content".localized)
                            .font(.caption)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 例3
                    VStack(alignment: .leading, spacing: 12) {
                        Label("ai_example_3_title".localized, systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.headline)
                            .foregroundColor(.green)

                        Text("ai_example_3_content".localized)
                            .font(.caption)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 注意点
                    VStack(alignment: .leading, spacing: 12) {
                        Label("ai_caution".localized, systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ai_caution_1".localized)
                            Text("ai_caution_2".localized)
                            Text("ai_caution_3".localized)
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("ai_prompt_hints".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HintItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Claude Code出力ビュー
struct ClaudeCodeExportView: View {
    let memoContent: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ExportTemplate = .general
    @State private var additionalContext: String = ""
    @State private var showCopied = false

    enum ExportTemplate: String, CaseIterable {
        case general = "general"
        case codeReview = "codeReview"
        case bugFix = "bugFix"
        case feature = "feature"
        case refactor = "refactor"

        var localizedName: String {
            switch self {
            case .general: return "ai_template_general".localized
            case .codeReview: return "ai_template_code_review".localized
            case .bugFix: return "ai_template_bug_fix".localized
            case .feature: return "ai_template_feature".localized
            case .refactor: return "ai_template_refactor".localized
            }
        }

        var icon: String {
            switch self {
            case .general: return "text.bubble"
            case .codeReview: return "eye"
            case .bugFix: return "ladybug"
            case .feature: return "plus.rectangle.on.rectangle"
            case .refactor: return "arrow.triangle.2.circlepath"
            }
        }

        var description: String {
            switch self {
            case .general: return "ai_template_general_desc".localized
            case .codeReview: return "ai_template_code_review_desc".localized
            case .bugFix: return "ai_template_bug_fix_desc".localized
            case .feature: return "ai_template_feature_desc".localized
            case .refactor: return "ai_template_refactor_desc".localized
            }
        }

        func generatePrompt(content: String, context: String) -> String {
            let contextSection = context.isEmpty ? "" : "\n\n## 追加コンテキスト\n\(context)"

            switch self {
            case .general:
                return """
                以下のタスクを実行してください。

                ## タスク内容
                \(content)\(contextSection)

                ## 注意事項
                - 必要に応じてコードベースを調査してください
                - 実装前に計画を立ててください
                - 変更内容を明確に説明してください
                """

            case .codeReview:
                return """
                以下の内容についてコードレビューを行ってください。

                ## レビュー対象
                \(content)\(contextSection)

                ## 確認ポイント
                - コードの品質と可読性
                - バグの可能性
                - パフォーマンスの問題
                - セキュリティ上の懸念
                - ベストプラクティスへの準拠

                レビュー結果を箇条書きでまとめてください。
                """

            case .bugFix:
                return """
                以下のバグを調査し、修正してください。

                ## バグの内容
                \(content)\(contextSection)

                ## 実施手順
                1. 関連するコードを特定する
                2. 原因を分析する
                3. 修正方法を提案する
                4. 修正を実装する
                5. 修正後のテスト方法を説明する

                原因と修正内容を明確に説明してください。
                """

            case .feature:
                return """
                以下の機能を実装してください。

                ## 実装する機能
                \(content)\(contextSection)

                ## 実装方針
                1. 既存のコードパターンに従う
                2. 適切なエラーハンドリングを追加
                3. 必要に応じてテストを作成
                4. コードにコメントを追加

                実装計画を立ててから作業を開始してください。
                """

            case .refactor:
                return """
                以下のコードをリファクタリングしてください。

                ## リファクタリング対象
                \(content)\(contextSection)

                ## 改善ポイント
                - コードの可読性向上
                - 重複コードの削減
                - 適切な抽象化
                - パフォーマンスの最適化
                - 命名の改善

                変更前後の比較と、改善点を説明してください。
                """
            }
        }
    }

    var generatedPrompt: String {
        selectedTemplate.generatePrompt(content: memoContent, context: additionalContext)
    }

    var body: some View {
        NavigationView {
            List {
                // テンプレート選択
                Section {
                    ForEach(ExportTemplate.allCases, id: \.rawValue) { template in
                        Button(action: {
                            selectedTemplate = template
                        }) {
                            HStack {
                                Image(systemName: template.icon)
                                    .foregroundColor(.green)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.localizedName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedTemplate == template {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                } header: {
                    Text("ai_template".localized)
                } footer: {
                    Text("ai_template_footer".localized)
                }

                // 追加コンテキスト
                Section {
                    TextEditor(text: $additionalContext)
                        .frame(minHeight: 80)
                } header: {
                    Text("ai_additional_context".localized)
                } footer: {
                    Text("ai_additional_context_footer".localized)
                }

                // プレビュー
                Section {
                    Text(generatedPrompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } header: {
                    Text("ai_generated_prompt".localized)
                }

                // コピーボタン
                Section {
                    Button(action: copyToClipboard) {
                        HStack {
                            Spacer()
                            if showCopied {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("ai_copied".localized)
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "doc.on.clipboard")
                                Text("ai_copy_to_clipboard".localized)
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(showCopied ? .green : .white)
                        .padding()
                        .background(showCopied ? Color.green.opacity(0.2) : Color.green)
                        .cornerRadius(12)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("ai_claude_code_output".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = generatedPrompt
        showCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

/// アレンジ結果表示ビュー
struct ArrangedResultView: View {
    let originalContent: String
    let arrangedContent: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    @State private var showComparison = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // アレンジ後のメモ
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("ai_after_arrange".localized)
                                .font(.headline)
                        }

                        Text(arrangedContent)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }

                    // 比較トグル
                    if showComparison {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("ai_original_memo".localized)
                                    .font(.headline)
                            }

                            Text(originalContent)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }

                    Button(action: {
                        showComparison.toggle()
                    }) {
                        HStack {
                            Image(systemName: showComparison ? "chevron.up" : "chevron.down")
                            Text(showComparison ? "ai_hide_original".localized : "ai_compare_original".localized)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    // アクションボタン
                    VStack(spacing: 12) {
                        Button(action: onApply) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("ai_apply_memo".localized)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }

                        Button(action: onDismiss) {
                            Text("ai_discard".localized)
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("ai_arrange_result".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MemoArrangeView(
        memoContent: .constant("今日は会議があって、新しいプロジェクトについて話し合いました。")
    )
}
