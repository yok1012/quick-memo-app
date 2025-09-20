import SwiftUI

struct TagManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedCategory: String = "仕事"
    @State private var showingAddTag = false
    @State private var newTagText = ""
    @State private var editingTag: String? = nil
    @State private var editingTagText = ""
    @State private var showingDeleteAlert = false
    @State private var tagToDelete: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categorySelector
                
                tagListView
                
                Spacer()
            }
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTag = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
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
            .alert("タグを削除", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    if let tag = tagToDelete {
                        deleteTag(tag)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("「\(tagToDelete ?? "")」を削除してもよろしいですか？")
            }
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dataManager.categories, id: \.id) { category in
                    CategoryTab(
                        category: category,
                        isSelected: selectedCategory == category.name
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category.name
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6))
    }
    
    private var tagListView: some View {
        Group {
            if let category = dataManager.getCategory(named: selectedCategory) {
                if category.defaultTags.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(category.defaultTags, id: \.self) { tag in
                                TagRow(
                                    tag: tag,
                                    isEditing: editingTag == tag,
                                    editingText: $editingTagText,
                                    onEdit: {
                                        startEditingTag(tag)
                                    },
                                    onSave: {
                                        saveEditedTag(oldTag: tag)
                                    },
                                    onDelete: {
                                        confirmDeleteTag(tag)
                                    }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            } else {
                emptyStateView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("タグがありません")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Button(action: {
                showingAddTag = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("タグを追加")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        dataManager.addTag(to: selectedCategory, tag: trimmed)
        newTagText = ""
    }
    
    private func startEditingTag(_ tag: String) {
        editingTag = tag
        editingTagText = tag
    }
    
    private func saveEditedTag(oldTag: String) {
        let trimmed = editingTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingTag = nil
            editingTagText = ""
            return
        }
        
        dataManager.updateTag(in: selectedCategory, oldTag: oldTag, newTag: trimmed)
        editingTag = nil
        editingTagText = ""
    }
    
    private func confirmDeleteTag(_ tag: String) {
        tagToDelete = tag
        showingDeleteAlert = true
    }
    
    private func deleteTag(_ tag: String) {
        dataManager.removeTag(from: selectedCategory, tag: tag)
        tagToDelete = nil
    }
}

struct CategoryTab: View {
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
            .padding(.vertical, 8)
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

struct TagRow: View {
    let tag: String
    let isEditing: Bool
    @Binding var editingText: String
    let onEdit: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            if isEditing {
                TextField("タグ名", text: $editingText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSave()
                    }
                
                Button(action: onSave) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(tag)
                        .font(.system(size: 16))
                    
                    Spacer()
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
}

#Preview {
    TagManagementView()
}