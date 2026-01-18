import SwiftUI

struct EditMemoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var memoText: String
    @State private var selectedCategory: String
    @State private var selectedTags: Set<String>
    @State private var selectedDuration: Int
    @State private var isExpanded: Bool = true
    @State private var showingDeleteAlert = false
    @State private var showingAddTag = false
    @State private var newTagText = ""
    @State private var showingTagLimitAlert = false
    @State private var showingPurchase = false
    @State private var showingTagExtraction = false
    @State private var showingMemoArrange = false
    @StateObject private var aiManager = AIManager.shared

    // テキストエリアの高さ調整用
    @AppStorage("editMemoTextAreaHeight") private var textAreaHeight: Double = 150
    @State private var isDragging = false
    private let minTextAreaHeight: CGFloat = 80
    private let maxTextAreaHeight: CGFloat = 400

    // ドラフト保存用
    @State private var hasDraft = false

    // エクスポート用
    @State private var showingExportOptions = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?

    let memo: QuickMemo
    private let draftKey: String

    init(memo: QuickMemo) {
        self.memo = memo
        self.draftKey = "editMemoDraft_\(memo.id.uuidString)"

        // ドラフトがあれば読み込む
        if let draftData = UserDefaults.standard.data(forKey: "editMemoDraft_\(memo.id.uuidString)"),
           let draft = try? JSONDecoder().decode(MemoDraft.self, from: draftData) {
            _memoText = State(initialValue: draft.content)
            _selectedCategory = State(initialValue: draft.category)
            _selectedTags = State(initialValue: Set(draft.tags))
            _selectedDuration = State(initialValue: draft.duration)
            _hasDraft = State(initialValue: true)
        } else {
            _memoText = State(initialValue: memo.content)
            _selectedCategory = State(initialValue: memo.primaryCategory)
            _selectedTags = State(initialValue: Set(memo.tags))
            _selectedDuration = State(initialValue: memo.durationMinutes)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                categorySelector
                
                textInputArea
                
                if isExpanded {
                    tagSection
                    durationSection
                }
                
                Spacer()
                
                deleteButton
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("メモを削除", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    deleteMemo()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("このメモを削除してもよろしいですか？")
            }
            .confirmationDialog("export_format".localized, isPresented: $showingExportOptions) {
                Button("settings_markdown_format".localized) {
                    exportMemo(format: ExportManager.ExportFormat.markdown)
                }
                Button("settings_text_format".localized) {
                    exportMemo(format: ExportManager.ExportFormat.plainText)
                }
                Button("settings_json_format".localized) {
                    exportMemo(format: ExportManager.ExportFormat.json)
                }
                Button("cancel".localized, role: .cancel) {}
            } message: {
                Text("export_select_format".localized)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            Text("edit_memo".localized)
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            // エクスポートボタン
            Button(action: {
                showingExportOptions = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
            .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

            // AI アレンジボタン
            Button(action: {
                showingMemoArrange = true
            }) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18))
                    .foregroundColor(.purple)
            }
            .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

            Button(action: {
                updateMemo()
            }) {
                Text("update".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(memoText.isEmpty ? Color.gray : Color.blue)
                    )
            }
            .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dataManager.categories, id: \.id) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category.name
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category.name
                            updateDefaultTags()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6))
    }
    
    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if memoText.isEmpty {
                    Text("メモを入力...")
                        .font(.system(size: 18))
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $memoText)
                    .font(.system(size: 18))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .frame(height: CGFloat(textAreaHeight))
                    .onChange(of: memoText) { _ in
                        saveDraft()
                    }
            }

            // 高さ調整用のドラッグハンドル
            resizeHandle

            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                        Text(isExpanded ? "オプションを隠す" : "オプションを表示")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                if hasDraft {
                    Button(action: {
                        discardDraft()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11))
                            Text("元に戻す")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.orange)
                    }
                }

                if !selectedTags.isEmpty {
                    Text("\(selectedTags.count)個のタグ")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private var resizeHandle: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(isDragging ? Color.blue : Color(.systemGray3))
                .frame(width: 40, height: 4)
            Spacer()
        }
        .frame(height: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newHeight = textAreaHeight + value.translation.height
                    textAreaHeight = min(max(Double(minTextAreaHeight), newHeight), Double(maxTextAreaHeight))
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category = dataManager.getCategory(named: selectedCategory) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // AI抽出ボタン
                        Button(action: {
                            showingTagExtraction = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .medium))
                                Text("AI抽出")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.purple.opacity(0.1))
                            )
                        }
                        .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20)
                        .opacity(memoText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 ? 0.5 : 1.0)

                        // 新規タグ追加ボタン
                        Button(action: {
                            showingAddTag = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .medium))
                                Text("new_category".localized)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )
                        }

                        ForEach(category.defaultTags, id: \.self) { tag in
                            QuickTagChip(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
        .alert("タグ数の制限", isPresented: $showingTagLimitAlert) {
            Button("Pro版を見る") {
                showingPurchase = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("無料版では1つのメモに15個までのタグを設定できます。Pro版では無制限にタグを追加できます。")
        }
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
        .sheet(isPresented: $showingTagExtraction) {
            TagExtractionView(memoContent: memoText, categoryName: selectedCategory, selectedTags: $selectedTags)
        }
        .sheet(isPresented: $showingMemoArrange) {
            MemoArrangeView(memoContent: $memoText)
        }
        .alert("新しいタグを追加", isPresented: $showingAddTag) {
            TextField("タグ名", text: $newTagText)
            Button("追加") {
                addNewTag()
            }
            Button("キャンセル", role: .cancel) {
                newTagText = ""
            }
        } message: {
            Text("\(selectedCategory)カテゴリーに新しいタグを追加します")
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("memo_duration".localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { duration in
                        DurationChip(
                            duration: duration,
                            isSelected: selectedDuration == duration
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDuration = duration
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var deleteButton: some View {
        Button(action: {
            showingDeleteAlert = true
        }) {
            HStack {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                Text("delete_memo_title".localized)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }
    
    private func toggleTag(_ tag: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                // タグ数制限のチェック
                let maxTags = purchaseManager.getMaxTagsPerMemo()
                if selectedTags.count >= maxTags && !purchaseManager.isProVersion {
                    showingTagLimitAlert = true
                } else {
                    selectedTags.insert(tag)
                }
            }
        }
    }
    
    private func updateDefaultTags() {
        if let category = dataManager.getCategory(named: selectedCategory) {
            selectedTags = Set(category.defaultTags.prefix(2))
        }
    }
    
    private func updateMemo() {
        let trimmedText = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        var updatedMemo = memo
        updatedMemo.content = trimmedText
        updatedMemo.primaryCategory = selectedCategory
        updatedMemo.tags = Array(selectedTags)
        updatedMemo.durationMinutes = selectedDuration
        updatedMemo.updatedAt = Date()

        dataManager.updateMemo(updatedMemo)

        // ドラフトをクリア
        clearDraft()

        // カレンダーイベントも更新（権限がある場合のみ）
        if CalendarService.shared.hasCalendarAccess {
            Task {
                updatedMemo.updateCalendarEvent()
            }
        }

        dismiss()
    }

    private func deleteMemo() {
        // カレンダーイベントを削除（権限がある場合のみ）
        if CalendarService.shared.hasCalendarAccess {
            var memoToDelete = memo
            memoToDelete.deleteCalendarEvent()
        }

        // ドラフトをクリア
        clearDraft()

        // メモを削除
        dataManager.deleteMemo(id: memo.id)

        dismiss()
    }

    private func exportMemo(format: ExportManager.ExportFormat) {
        // 現在の入力内容から一時メモを作成
        let tempMemo = QuickMemo(
            id: memo.id,
            title: memo.title,
            content: memoText,
            primaryCategory: selectedCategory,
            tags: Array(selectedTags),
            createdAt: memo.createdAt,
            updatedAt: Date(),
            calendarEventId: nil,
            durationMinutes: selectedDuration
        )

        do {
            let data = try ExportManager.shared.exportSingleMemo(tempMemo, format: format)

            let fileExtension: String
            switch format {
            case .markdown:
                fileExtension = "md"
            case .plainText:
                fileExtension = "txt"
            case .json:
                fileExtension = "json"
            case .csv:
                fileExtension = "csv"
            }

            let fileName = "memo_\(Date().timeIntervalSince1970).\(fileExtension)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)

            exportedFileURL = tempURL
            showingShareSheet = true
        } catch {
            print("Export error: \(error)")
        }
    }

    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // タグ数制限のチェック
        let maxTags = purchaseManager.getMaxTagsPerMemo()
        if selectedTags.count >= maxTags && !purchaseManager.isProVersion {
            showingTagLimitAlert = true
            newTagText = ""
            return
        }

        if dataManager.addTag(to: selectedCategory, tag: trimmed) {
            selectedTags.insert(trimmed)  // 新しいタグを自動選択
        } else {
            // タグ追加に失敗（制限に達した）
            showingTagLimitAlert = true
        }
        newTagText = ""
    }

    // MARK: - ドラフト管理

    private func saveDraft() {
        // 元のメモと異なる場合のみドラフトを保存
        let hasChanges = memoText != memo.content ||
                        selectedCategory != memo.primaryCategory ||
                        Set(memo.tags) != selectedTags ||
                        selectedDuration != memo.durationMinutes

        if hasChanges {
            let draft = MemoDraft(
                content: memoText,
                category: selectedCategory,
                tags: Array(selectedTags),
                duration: selectedDuration
            )
            if let data = try? JSONEncoder().encode(draft) {
                UserDefaults.standard.set(data, forKey: draftKey)
                hasDraft = true
            }
        } else {
            clearDraft()
        }
    }

    private func discardDraft() {
        // 元のメモ内容に戻す
        memoText = memo.content
        selectedCategory = memo.primaryCategory
        selectedTags = Set(memo.tags)
        selectedDuration = memo.durationMinutes
        clearDraft()
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
        hasDraft = false
    }
}

// MARK: - ドラフト用のデータ構造
struct MemoDraft: Codable {
    let content: String
    let category: String
    let tags: [String]
    let duration: Int
}

#Preview {
    EditMemoView(memo: QuickMemo(
        content: "サンプルメモ",
        primaryCategory: "仕事",
        tags: ["重要", "TODO"]
    ))
}