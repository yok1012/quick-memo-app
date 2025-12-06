import SwiftUI

struct FastInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @StateObject private var quickInputManager = QuickInputManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared

    @State private var selectedCategory: String
    @State private var memoTitle: String = ""  // タイトル用のステート変数を追加
    @State private var memoText: String = ""
    @State private var isExpanded: Bool = false
    @State private var selectedTags: Set<String> = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var isComposing: Bool = false
    @State private var selectedDuration: Int = 30  // デフォルト30分
    @State private var showingAddTag = false
    @State private var newTagText = ""
    @State private var showingTagLimitAlert = false
    @State private var showingPurchase = false
    
    init(defaultCategory: String? = nil) {
        _selectedCategory = State(initialValue: defaultCategory ?? QuickInputManager.shared.getQuickCategory())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                categorySelector

                titleInputArea

                textInputArea

                if isExpanded {
                    tagSection
                    durationSection
                }

                Spacer()
            }
            .id(localizationManager.refreshID)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
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
            
            Text("Quick Memo")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            Button(action: {
                saveMemo()
            }) {
                Text("save".localized)
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
    
    private var titleInputArea: some View {
        VStack(spacing: 0) {
            TextField("memo_title_optional".localized, text: $memoTitle)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))

            Divider()
        }
    }

    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if memoText.isEmpty && !isComposing {
                    Text("memo_placeholder".localized)
                        .font(.system(size: 18))
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $memoText)
                    .focused($isTextFieldFocused)
                    .font(.system(size: 18))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .frame(minHeight: 100, maxHeight: 150)
                    .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidBeginEditingNotification)) { _ in
                        isComposing = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidEndEditingNotification)) { _ in
                        isComposing = false
                    }
            }
            
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                        if isExpanded {
                            updateDefaultTags()
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                        Text(isExpanded ? "memo_tags_hide".localized : "memo_tags_add".localized)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !selectedTags.isEmpty {
                    Text("memo_tags_count".localized(with: selectedTags.count))
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
                                Text("add".localized)
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
        .alert("memo_new_tag".localized, isPresented: $showingAddTag) {
            TextField("memo_tag_name".localized, text: $newTagText)
            Button("add".localized) {
                addNewTag()
            }
            Button("cancel".localized, role: .cancel) {
                newTagText = ""
            }
        } message: {
            Text(localizationManager.localizedString(for: "add_tag_to_category", arguments: selectedCategory))
        }
        .alert("memo_tag_limit".localized, isPresented: $showingTagLimitAlert) {
            Button("pro_view".localized) {
                showingPurchase = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("tag_limit_message".localized)
        }
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("memo_calendar_duration".localized)
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
    
    private func toggleTag(_ tag: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                // タグ数制限のチェック
                let maxTags = purchaseManager.getMaxTagsPerMemo()
                if selectedTags.count >= maxTags && !purchaseManager.isProVersion {
                    // 無料版で制限に達している場合、アラートを表示
                    showingTagLimitAlert = true
                } else {
                    selectedTags.insert(tag)
                }
            }
        }
    }
    
    private func updateDefaultTags() {
        if let category = dataManager.getCategory(named: selectedCategory) {
            // 自動的に最初の2つのタグを選択
            selectedTags = Set(category.defaultTags.prefix(2))
        }
    }
    
    private func saveMemo() {
        let trimmedText = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let memo = QuickMemo(
            title: memoTitle.trimmingCharacters(in: .whitespacesAndNewlines),  // タイトルを追加
            content: trimmedText,
            primaryCategory: selectedCategory,
            tags: Array(selectedTags),
            durationMinutes: selectedDuration
        )
        
        dataManager.addMemo(memo)
        quickInputManager.recordCategoryUsage(selectedCategory)
        
        // カレンダー連携（権限がある場合のみ）
        if CalendarService.shared.hasCalendarAccess {
            Task {
                let eventId = await CalendarService.shared.createCalendarEvent(for: memo)
                if let eventId = eventId {
                    await MainActor.run {
                        var updatedMemo = memo
                        updatedMemo.calendarEventId = eventId
                        dataManager.updateMemo(updatedMemo)
                    }
                } else {
                    if let error = CalendarService.shared.lastError {
                    }
                }
            }
        } else {
        }
        
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

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(category.name)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: category.color) : Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(Color(hex: category.color).opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct QuickTagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("#\(tag)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
    }
}

struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void
    
    var durationText: String {
        if duration < 60 {
            return "\(duration)\("memo_minutes".localized)"
        } else {
            let hours = duration / 60
            let minutes = duration % 60
            if minutes == 0 {
                return "\(hours)\("memo_hours".localized)"
            } else {
                return "\(hours)\("memo_hours".localized)\(minutes)\("memo_minutes".localized)"
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(durationText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
    }
}

#Preview {
    FastInputView()
}