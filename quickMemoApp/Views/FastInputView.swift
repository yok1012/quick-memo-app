import SwiftUI

struct FastInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var quickInputManager = QuickInputManager.shared
    
    @State private var selectedCategory: String
    @State private var memoText: String = ""
    @State private var isExpanded: Bool = false
    @State private var selectedTags: Set<String> = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var isComposing: Bool = false
    
    init(defaultCategory: String? = nil) {
        _selectedCategory = State(initialValue: defaultCategory ?? QuickInputManager.shared.getQuickCategory())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                categorySelector
                
                textInputArea
                
                if isExpanded {
                    tagSection
                }
                
                Spacer()
            }
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
                Text("保存")
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
                if memoText.isEmpty && !isComposing {
                    Text("メモを入力...")
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
                        Text(isExpanded ? "タグを隠す" : "タグを追加")
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
    }
    
    private func toggleTag(_ tag: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
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
            content: trimmedText,
            primaryCategory: selectedCategory,
            tags: Array(selectedTags)
        )
        
        dataManager.addMemo(memo)
        quickInputManager.recordCategoryUsage(selectedCategory)
        
        // カレンダー連携
        Task {
            var mutableMemo = memo
            mutableMemo.createCalendarEvent()
        }
        
        dismiss()
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

#Preview {
    FastInputView()
}