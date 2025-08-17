import SwiftUI

struct QuickMemoInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var quickInputManager = QuickInputManager.shared
    @State private var memoText = ""
    @State private var selectedCategory: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                
                quickCategorySelector
                
                textInputArea
                
                quickSaveButton
                
                Spacer()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                selectedCategory = quickInputManager.getQuickCategory()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("閉じる") {
                dismiss()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Text("クイックメモ")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            Button("保存") {
                saveMemo()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(canSave ? .blue : .secondary)
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }
    
    private var quickCategorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(quickInputManager.preloadCategories(), id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: iconForCategory(category))
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(category)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedCategory == category ? Color.blue : Color(.systemGray6))
                        )
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedCategory)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("メモを入力してください...", text: $memoText, axis: .vertical)
                .focused($isTextFieldFocused)
                .font(.system(size: 18))
                .lineLimit(8, reservesSpace: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal, 20)
        }
    }
    
    private var quickSaveButton: some View {
        Button(action: {
            saveMemo()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                
                Text("保存")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSave ? Color.blue : Color.gray)
            )
        }
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var canSave: Bool {
        !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedCategory.isEmpty
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "仕事": return "briefcase"
        case "プライベート": return "house"
        case "アイデア": return "lightbulb"
        case "人物": return "person"
        default: return "folder"
        }
    }
    
    private func saveMemo() {
        let trimmedText = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !selectedCategory.isEmpty else { return }
        
        let memo = QuickMemo(
            content: trimmedText,
            primaryCategory: selectedCategory,
            tags: []
        )
        
        dataManager.addMemo(memo)
        quickInputManager.recordCategoryUsage(selectedCategory)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            dismiss()
        }
    }
}

#Preview {
    QuickMemoInputView()
}