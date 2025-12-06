import SwiftUI

struct CategoryTagManagementView: View {
    let category: Category
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @State private var searchText = ""
    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var showDeleteAlert = false
    @State private var tagToDelete: String?

    private var allTags: [(tag: String, isHidden: Bool, count: Int)] {
        let tagsInfo = dataManager.getAllTagsForCategory(categoryId: category.id)
        return tagsInfo.map { tagInfo in
            let count = dataManager.memos
                .filter { $0.primaryCategory == category.name && $0.tags.contains(tagInfo.tag) }
                .count
            return (tag: tagInfo.tag, isHidden: tagInfo.isHidden, count: count)
        }
    }

    private var filteredTags: [(tag: String, isHidden: Bool, count: Int)] {
        if searchText.isEmpty {
            return allTags
        } else {
            return allTags.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // カテゴリー情報ヘッダー
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: category.color))

                    VStack(alignment: .leading) {
                        Text(category.name)
                            .font(.system(size: 20, weight: .semibold))
                        Text("\(allTags.count) \("tags".localized)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: category.color).opacity(0.1))
                )
                .padding(.horizontal)
                .padding(.top)

                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("search_tags".localized, text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)

                // タグリスト
                if filteredTags.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("no_tags_yet".localized)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("tags_will_appear_here".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTags, id: \.tag) { tagInfo in
                            HStack {
                                // タグアイコンと名前
                                HStack(spacing: 8) {
                                    Image(systemName: "number")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: category.color))

                                    Text(tagInfo.tag)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(tagInfo.isHidden ? .secondary : .primary)

                                    if tagInfo.isHidden {
                                        Image(systemName: "eye.slash")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                // メモ数
                                Text("\(tagInfo.count)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.1))
                                    )

                                // 表示/非表示トグル
                                Button(action: {
                                    withAnimation {
                                        dataManager.toggleTagVisibility(tag: tagInfo.tag, for: category.id)
                                    }
                                }) {
                                    Image(systemName: tagInfo.isHidden ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(tagInfo.isHidden ? .secondary : Color(hex: category.color))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteTags)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("tag_management".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTag = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showAddTag) {
                AddTagView(category: category)
            }
            .alert("delete_tag_title".localized, isPresented: $showDeleteAlert) {
                Button("delete".localized, role: .destructive) {
                    if let tag = tagToDelete {
                        deleteTag(tag)
                    }
                }
                Button("cancel".localized, role: .cancel) {
                    tagToDelete = nil
                }
            } message: {
                if let tag = tagToDelete {
                    Text(String(format: "delete_tag_message".localized, tag))
                }
            }
        }
    }

    private func deleteTags(offsets: IndexSet) {
        for index in offsets {
            let tag = filteredTags[index].tag
            tagToDelete = tag
            showDeleteAlert = true
        }
    }

    private func deleteTag(_ tag: String) {
        withAnimation {
            // カテゴリーからタグを削除
            if let categoryIndex = dataManager.categories.firstIndex(where: { $0.id == category.id }) {
                dataManager.categories[categoryIndex].defaultTags.removeAll { $0 == tag }
                dataManager.categories[categoryIndex].hiddenTags.remove(tag)
                dataManager.saveCategories()
            }

            // メモからもタグを削除（オプション）
            // for index in dataManager.memos.indices {
            //     if dataManager.memos[index].primaryCategory == category.name {
            //         dataManager.memos[index].tags.removeAll { $0 == tag }
            //     }
            // }
            // dataManager.saveMemos()
        }
        tagToDelete = nil
    }
}

// タグ追加画面
struct AddTagView: View {
    let category: Category
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @State private var tagName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("add_tag_to_category".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                HStack {
                    Text("#")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: category.color))

                    TextField("tag_name".localized, text: $tagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            addTag()
                        }
                }

                Text("tag_add_hint".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("add_tag".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("add".localized) {
                        addTag()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }

    private func addTag() {
        let trimmedTag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }

        // カテゴリーにタグを追加
        dataManager.addTagsToCategory(tags: [trimmedTag], categoryName: category.name)
        dismiss()
    }
}