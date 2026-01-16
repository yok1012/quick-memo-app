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
                Section("元のメモ") {
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
                                Text("Claude Code用プロンプト出力")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text("AIアシスタント向けのプロンプトとしてコピー")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("外部AI連携")
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
                    Text("プリセット")
                } footer: {
                    Text("よく使われる編集パターンから選択できます")
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
                                Label("削除", systemImage: "trash")
                            }

                            Button {
                                editingPrompt = prompt
                                showEditPrompt = true
                            } label: {
                                Label("編集", systemImage: "pencil")
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

                                Text("カスタムプロンプトを追加")
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

                            Text("プロンプト作成のヒント")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("カスタムプロンプト")
                } footer: {
                    Text("最大3つまで保存可能。左スワイプで編集・削除")
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
                    Text("一時的な指示（保存されません）")
                } footer: {
                    Text("今回だけ使う指示を入力。よく使う場合は上のカスタムプロンプトに保存してください")
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
                                Text("処理中...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("メモをアレンジ")
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
                        Text("今月の使用")
                        Spacer()
                        Text("\(aiManager.usageStats.totalRequests)/\(aiManager.usageStats.monthlyLimit)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("残り回数")
                        Spacer()
                        Text("\(aiManager.usageStats.remainingRequests)")
                            .foregroundColor(aiManager.usageStats.isQuotaExceeded ? .red : .green)
                    }
                } header: {
                    Text("使用統計")
                }
            }
            .navigationTitle("メモアレンジ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
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
            ("summarize", "要約", "3行以内で簡潔にまとめます", "text.alignleft", .blue),
            ("business", "ビジネス文書化", "フォーマルな文章に変換します", "briefcase.fill", .orange),
            ("casual", "カジュアル化", "親しみやすい文章にします", "message.fill", .green),
            ("expand", "詳細化", "より具体的に展開します", "arrow.up.left.and.arrow.down.right", .purple),
            ("bullets", "箇条書き化", "見やすく整理します", "list.bullet", .indigo),
            ("translate_en", "英語に翻訳", "英語に翻訳します", "globe", .cyan),
            ("translate_ja", "日本語に翻訳", "日本語に翻訳します", "globe", .pink)
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
                    TextField("プロンプト名（例：議事録形式）", text: $name)
                } header: {
                    Text("名前")
                } footer: {
                    Text("わかりやすい短い名前をつけてください")
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
                    Text("アイコン")
                }

                Section {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 150)
                } header: {
                    Text("プロンプト内容")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 ヒント:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("• 「〜してください」のように明確な指示を書く")
                        Text("• 出力形式を指定すると安定した結果に")
                        Text("• 例: 「以下を議事録形式にまとめてください。日時、参加者、議題、決定事項、次回アクションの項目で整理してください。」")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle(mode.isAdd ? "プロンプトを追加" : "プロンプトを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
                        Label("基本原則", systemImage: "1.circle.fill")
                            .font(.headline)
                            .foregroundColor(.blue)

                        Text("プロンプトには以下の要素を含めると効果的です：")
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 8) {
                            HintItem(icon: "target", text: "目的: 何をしたいか明確に")
                            HintItem(icon: "doc.text", text: "形式: 出力の形式を指定")
                            HintItem(icon: "ruler", text: "制約: 文字数や条件を指定")
                            HintItem(icon: "person.fill", text: "トーン: 文体やニュアンス")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 例1
                    VStack(alignment: .leading, spacing: 12) {
                        Label("例1: 議事録形式", systemImage: "doc.richtext")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text("以下の内容を議事録形式で整理してください。\n\n【形式】\n• 日時\n• 参加者（推測可能なら）\n• 議題\n• 決定事項\n• 次回アクション\n\n簡潔に箇条書きでまとめてください。")
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
                        Label("例2: SNS投稿用", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .foregroundColor(.pink)

                        Text("以下の内容をTwitter投稿用に変換してください。\n\n【条件】\n• 140文字以内\n• 絵文字を2-3個使用\n• ハッシュタグを1-2個提案\n• 興味を引く書き出しに")
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
                        Label("例3: コードレビュー依頼", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.headline)
                            .foregroundColor(.green)

                        Text("以下のメモをコードレビュー依頼文に変換してください。\n\n【含める項目】\n• 変更の背景・目的\n• 主な変更点（箇条書き）\n• 特に見てほしいポイント\n• 影響範囲\n\n丁寧かつ簡潔な文体で。")
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
                        Label("注意点", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 曖昧な指示は避ける（「いい感じに」→NG）")
                            Text("• 具体的な条件を明示する")
                            Text("• 出力例を示すとより正確に")
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("プロンプト作成のヒント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
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
        case general = "汎用"
        case codeReview = "コードレビュー"
        case bugFix = "バグ修正"
        case feature = "機能実装"
        case refactor = "リファクタリング"

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
            case .general: return "汎用的なタスク依頼"
            case .codeReview: return "コードのレビュー依頼"
            case .bugFix: return "バグの調査・修正依頼"
            case .feature: return "新機能の実装依頼"
            case .refactor: return "コードの改善依頼"
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
                                    Text(template.rawValue)
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
                    Text("テンプレート")
                } footer: {
                    Text("用途に合わせたテンプレートを選択してください")
                }

                // 追加コンテキスト
                Section {
                    TextEditor(text: $additionalContext)
                        .frame(minHeight: 80)
                } header: {
                    Text("追加コンテキスト（任意）")
                } footer: {
                    Text("ファイルパス、関連する情報など補足事項があれば入力")
                }

                // プレビュー
                Section {
                    Text(generatedPrompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } header: {
                    Text("生成されるプロンプト")
                }

                // コピーボタン
                Section {
                    Button(action: copyToClipboard) {
                        HStack {
                            Spacer()
                            if showCopied {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("コピーしました！")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "doc.on.clipboard")
                                Text("クリップボードにコピー")
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
            .navigationTitle("Claude Code出力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
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
                            Text("アレンジ後")
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
                                Text("元のメモ")
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
                            Text(showComparison ? "元のメモを隠す" : "元のメモと比較")
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
                                Text("このメモを適用")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }

                        Button(action: onDismiss) {
                            Text("破棄")
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
            .navigationTitle("アレンジ結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
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
