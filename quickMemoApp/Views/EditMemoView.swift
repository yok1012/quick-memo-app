import SwiftUI

struct EditMemoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
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
    
    let memo: QuickMemo
    
    init(memo: QuickMemo) {
        self.memo = memo
        _memoText = State(initialValue: memo.content)
        _selectedCategory = State(initialValue: memo.primaryCategory)
        _selectedTags = State(initialValue: Set(memo.tags))
        _selectedDuration = State(initialValue: memo.durationMinutes)
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
            
            Text("メモを編集")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            Button(action: {
                updateMemo()
            }) {
                Text("更新")
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
                    .frame(minHeight: 100, maxHeight: 150)
            }
            
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
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category = dataManager.getCategory(named: selectedCategory) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 新規タグ追加ボタン
                        Button(action: {
                            showingAddTag = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .medium))
                                Text("新規")
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
            Text("カレンダーの期間")
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
                Text("メモを削除")
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
        
        // メモを削除
        dataManager.deleteMemo(id: memo.id)
        
        dismiss()
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
}

#Preview {
    EditMemoView(memo: QuickMemo(
        content: "サンプルメモ",
        primaryCategory: "仕事",
        tags: ["重要", "TODO"]
    ))
}