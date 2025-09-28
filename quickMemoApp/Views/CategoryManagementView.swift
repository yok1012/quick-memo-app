import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var editMode: EditMode = .inactive
    @State private var showingAddCategory = false
    @State private var showingEditCategory = false
    @State private var selectedCategory: Category?
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category?
    @State private var showingProAlert = false

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
                .onMove(perform: purchaseManager.isProVersion ? moveCategories : nil)
                .onDelete(perform: purchaseManager.isProVersion ? deleteCategories : nil)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("category_management".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if purchaseManager.isProVersion {
                            EditButton()
                        }

                        Button(action: {
                            if purchaseManager.isProVersion {
                                showingAddCategory = true
                            } else {
                                showingProAlert = true
                            }
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
            .alert("category_delete_confirm".localized, isPresented: $showingDeleteAlert) {
                Button("cancel".localized, role: .cancel) {
                    categoryToDelete = nil
                }
                Button("delete".localized, role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                if let category = categoryToDelete {
                    let memoCount = dataManager.memos.filter { $0.primaryCategory == category.name }.count
                    if memoCount > 0 {
                        Text(String(format: "delete_category_with_memos".localized, category.name, memoCount))
                    } else {
                        Text(String(format: "delete_category_confirm_message".localized, category.name))
                    }
                }
            }
            .alert("category_pro_required".localized, isPresented: $showingProAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("category_free_limit_message".localized)
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
                Text("\(memoCount)\("items_count".localized)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if category.name != "other".localized && PurchaseManager.shared.isProVersion {
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
                Section("category_basic_info".localized) {
                    TextField("category_name_placeholder".localized, text: $categoryName)
                        .textInputAutocapitalization(.never)
                }

                Section("category_icon".localized) {
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

                Section("category_color".localized) {
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

                Section("category_default_tags".localized) {
                    TextField("comma_separated_tags".localized, text: $defaultTags)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("category_new".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("add".localized) {
                        addCategory()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("error_prefix".localized, isPresented: $showingError) {
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
            errorMessage = "category_exists_error".localized
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
                Section("category_basic_info".localized) {
                    if category.name == "other".localized {
                        HStack {
                            Text("category_name_placeholder".localized)
                            Spacer()
                            Text(categoryName)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        TextField("category_name_placeholder".localized, text: $categoryName)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("category_icon".localized) {
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

                Section("category_color".localized) {
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

                Section("category_default_tags".localized) {
                    TextField("comma_separated_tags".localized, text: $defaultTags)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("category_edit".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        saveCategory()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("error_prefix".localized, isPresented: $showingError) {
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