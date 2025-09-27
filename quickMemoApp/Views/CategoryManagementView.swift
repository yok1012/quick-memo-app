import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var editMode: EditMode = .inactive
    @State private var showingAddCategory = false
    @State private var showingEditCategory = false
    @State private var selectedCategory: Category?
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category?

    var body: some View {
        NavigationStack {
            List {
                ForEach(dataManager.categories.sorted(by: { $0.order < $1.order })) { category in
                    CategoryRow(
                        category: category,
                        onEdit: {
                            selectedCategory = category
                            showingEditCategory = true
                        },
                        onDelete: {
                            if dataManager.canDeleteCategory(category) {
                                categoryToDelete = category
                                showingDeleteAlert = true
                            }
                        }
                    )
                    .deleteDisabled(!dataManager.canDeleteCategory(category))
                }
                .onMove(perform: moveCategories)
                .onDelete(perform: deleteCategories)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("カテゴリー管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        EditButton()

                        Button(action: {
                            showingAddCategory = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
            .sheet(item: $selectedCategory) { category in
                EditCategoryView(category: category)
            }
            .alert("カテゴリーを削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {
                    categoryToDelete = nil
                }
                Button("削除", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                if let category = categoryToDelete {
                    let memoCount = dataManager.memos.filter { $0.primaryCategory == category.name }.count
                    if memoCount > 0 {
                        Text("「\(category.name)」カテゴリーを削除しますか？\n\n\(memoCount)件のメモが「その他」カテゴリーに移動されます。")
                    } else {
                        Text("「\(category.name)」カテゴリーを削除しますか？")
                    }
                }
            }
        }
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reorderedCategories = dataManager.categories.sorted(by: { $0.order < $1.order })
        reorderedCategories.move(fromOffsets: source, toOffset: destination)

        // Update order values
        for (index, category) in reorderedCategories.enumerated() {
            if let dataIndex = dataManager.categories.firstIndex(where: { $0.id == category.id }) {
                dataManager.categories[dataIndex].order = index
            }
        }

        dataManager.reorderCategories(reorderedCategories)
    }

    private func deleteCategory(_ category: Category) {
        withAnimation {
            dataManager.deleteCategory(id: category.id)
        }
        categoryToDelete = nil
    }

    private func deleteCategories(offsets: IndexSet) {
        let sortedCategories = dataManager.categories.sorted(by: { $0.order < $1.order })
        for index in offsets {
            let category = sortedCategories[index]
            if dataManager.canDeleteCategory(category) {
                categoryToDelete = category
                showingDeleteAlert = true
                // Note: Only show alert for the first deletable item when multiple are selected
                break
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void

    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: category.color))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 16, weight: .medium))

                if !category.defaultTags.isEmpty {
                    Text(category.defaultTags.prefix(3).joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Text("\(memoCount)件")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if category.name != "その他" {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var memoCount: Int {
        dataManager.memos.filter { $0.primaryCategory == category.name }.count
    }
}

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared

    @State private var categoryName = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = "#007AFF"
    @State private var defaultTags = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    let availableIcons = [
        "folder", "briefcase", "house", "lightbulb", "person",
        "star", "heart", "flag", "bookmark", "tag",
        "cart", "airplane", "car", "book", "music.note",
        "gamecontroller", "camera", "phone", "envelope", "gift"
    ]

    let availableColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE",
        "#5856D6", "#FF2D55", "#A2845E", "#32ADE6", "#8E8E93"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("カテゴリー名", text: $categoryName)
                        .textInputAutocapitalization(.never)
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color(.systemGray5))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("カラー") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                        ForEach(availableColors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("デフォルトタグ") {
                    TextField("カンマ区切りで入力 (例: 会議, タスク, 締切)", text: $defaultTags)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("新規カテゴリー")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addCategory()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addCategory() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if category name already exists
        if dataManager.categories.contains(where: { $0.name == trimmedName }) {
            errorMessage = "同じ名前のカテゴリーが既に存在します"
            showingError = true
            return
        }

        // Parse tags
        let tags = defaultTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Create new category
        let newOrder = (dataManager.categories.map { $0.order }.max() ?? -1) + 1
        let newCategory = Category(
            name: trimmedName,
            icon: selectedIcon,
            color: selectedColor,
            order: newOrder,
            defaultTags: tags
        )

        dataManager.addCategory(newCategory)
        dismiss()
    }
}

struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared

    let category: Category
    @State private var categoryName: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var defaultTags: String
    @State private var showingError = false
    @State private var errorMessage = ""

    init(category: Category) {
        self.category = category
        _categoryName = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.color)
        _defaultTags = State(initialValue: category.defaultTags.joined(separator: ", "))
    }

    let availableIcons = [
        "folder", "briefcase", "house", "lightbulb", "person",
        "star", "heart", "flag", "bookmark", "tag",
        "cart", "airplane", "car", "book", "music.note",
        "gamecontroller", "camera", "phone", "envelope", "gift"
    ]

    let availableColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE",
        "#5856D6", "#FF2D55", "#A2845E", "#32ADE6", "#8E8E93"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    if category.name == "その他" {
                        HStack {
                            Text("カテゴリー名")
                            Spacer()
                            Text(categoryName)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        TextField("カテゴリー名", text: $categoryName)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color(.systemGray5))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("カラー") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                        ForEach(availableColors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("デフォルトタグ") {
                    TextField("カンマ区切りで入力 (例: 会議, タスク, 締切)", text: $defaultTags)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("カテゴリー編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveCategory() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if renaming is allowed
        if category.name != trimmedName {
            if !dataManager.canRenameCategory(from: category.name, to: trimmedName) {
                errorMessage = category.name == "その他" ?
                    "「その他」カテゴリーの名前は変更できません" :
                    "同じ名前のカテゴリーが既に存在します"
                showingError = true
                return
            }
        }

        // Parse tags
        let tags = defaultTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Update category
        var updatedCategory = category
        if category.name != "その他" {
            updatedCategory.name = trimmedName
        }
        updatedCategory.icon = selectedIcon
        updatedCategory.color = selectedColor
        updatedCategory.defaultTags = tags

        dataManager.updateCategory(updatedCategory)
        dismiss()
    }
}

#Preview {
    CategoryManagementView()
}