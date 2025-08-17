import SwiftUI

struct MemoInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    
    private var category: Category? {
        dataManager.getCategory(named: categoryName)
    }
    
    let categoryName: String
    @State private var memoText = ""
    @State private var selectedTags: Set<String> = []
    @State private var customTag = ""
    @State private var showingTagInput = false
    @State private var suggestedTags: [String] = []
    @StateObject private var tagManager = TagManager.shared
    @FocusState private var isTextFieldFocused: Bool
    
    init(categoryName: String) {
        self.categoryName = categoryName
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                textInputArea
                
                tagSection
                
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
            Button("キャンセル") {
                dismiss()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(categoryName)
                    .font(.system(size: 20, weight: .bold))
                
                if let cat = category {
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .foregroundColor(Color(hex: cat.color))
                        Text("新しいメモ")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button("保存") {
                saveMemo()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
            .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("ここにメモを入力してください...", text: $memoText, axis: .vertical)
                .focused($isTextFieldFocused)
                .font(.system(size: 18))
                .lineLimit(10, reservesSpace: true)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .submitLabel(.done)
                .onChange(of: memoText) { newValue in
                    updateTagSuggestions(newValue)
                }
            
            Divider()
                .padding(.horizontal, 20)
        }
    }
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("タグ")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    showingTagInput = true
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
                .padding(.trailing, 20)
            }
            
            if let cat = category {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cat.defaultTags, id: \.self) { tag in
                            TagButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTag(tag)
                            }
                        }
                        
                        ForEach(Array(selectedTags.subtracting(cat.defaultTags)), id: \.self) { tag in
                            TagButton(
                                tag: tag,
                                isSelected: true,
                                isCustom: true
                            ) {
                                toggleTag(tag)
                            }
                        }
                        
                        if !suggestedTags.isEmpty {
                            ForEach(suggestedTags.filter { !selectedTags.contains($0) && !(cat.defaultTags.contains($0)) }, id: \.self) { tag in
                                TagButton(
                                    tag: tag,
                                    isSelected: false,
                                    isSuggested: true
                                ) {
                                    toggleTag(tag)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .alert("カスタムタグを追加", isPresented: $showingTagInput) {
            TextField("タグ名", text: $customTag)
            Button("追加") {
                if !customTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    selectedTags.insert(customTag.trimmingCharacters(in: .whitespacesAndNewlines))
                    customTag = ""
                }
            }
            Button("キャンセル", role: .cancel) {
                customTag = ""
            }
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func saveMemo() {
        let trimmedText = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let memo = QuickMemo(
            content: trimmedText,
            primaryCategory: categoryName,
            tags: Array(selectedTags)
        )
        
        dataManager.addMemo(memo)
        tagManager.recordTagUsage(Array(selectedTags))
        dismiss()
    }
    
    private func updateTagSuggestions(_ text: String) {
        suggestedTags = tagManager.generateTagSuggestions(for: text, category: categoryName)
    }
}

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let isCustom: Bool
    let isSuggested: Bool
    let action: () -> Void
    
    init(tag: String, isSelected: Bool, isCustom: Bool = false, isSuggested: Bool = false, action: @escaping () -> Void) {
        self.tag = tag
        self.isSelected = isSelected
        self.isCustom = isCustom
        self.isSuggested = isSuggested
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSuggested {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                
                Text("#\(tag)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if isCustom && isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColorForTag)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var backgroundColorForTag: Color {
        if isSelected {
            return Color.blue
        } else if isSuggested {
            return Color.orange.opacity(0.2)
        } else {
            return Color(.systemGray6)
        }
    }
}

#Preview {
    MemoInputView(categoryName: "仕事")
}