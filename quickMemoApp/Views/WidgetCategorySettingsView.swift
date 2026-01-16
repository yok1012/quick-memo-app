import SwiftUI

struct WidgetCategorySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var selectedCategories: Set<String> = []
    @State private var showingPurchaseAlert = false
    @State private var showingSaveConfirmation = false
    @State private var showingPurchase = false

    init() {
        // Load current widget categories
        let currentCategories = DataManager.shared.getWidgetCategories()
        _selectedCategories = State(initialValue: Set(currentCategories))
    }

    var body: some View {
        NavigationStack {
            VStack {
                if !purchaseManager.isProVersion {
                    ProUpgradeCard(onTapUpgrade: { showingPurchase = true })
                }

                List {
                    Section {
                        ForEach(dataManager.categories.sorted(by: { $0.order < $1.order })) { category in
                            CategorySelectionRow(
                                category: category,
                                isSelected: selectedCategories.contains(category.name),
                                isDisabled: !canSelectCategory(category.name),
                                onToggle: { isSelected in
                                    toggleCategory(category.name, isSelected: isSelected)
                                }
                            )
                        }
                    } header: {
                        Text("widget_display_categories".localized)
                    } footer: {
                        if !purchaseManager.isProVersion {
                            Text("widget_free_version_notice".localized)
                                .foregroundColor(.secondary)
                        } else {
                            Text("最大8つまで選択できます（大サイズウィジェット対応）")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("ウィジェット設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                    }
                    .disabled(!hasChanges())
                }
            }
            .alert("Pro版が必要です", isPresented: $showingPurchaseAlert) {
                Button("Pro版を見る") {
                    showingPurchase = true
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("ウィジェットのカテゴリーをカスタマイズするにはPro版へのアップグレードが必要です")
            }
            .alert("設定を保存しました", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("widget_updated".localized)
            }
            .sheet(isPresented: $showingPurchase) {
                PurchaseView()
            }
        }
    }

    private func canSelectCategory(_ categoryName: String) -> Bool {
        if !purchaseManager.isProVersion {
            // Free users can only keep currently selected categories
            return selectedCategories.contains(categoryName)
        }
        return true
    }

    private func toggleCategory(_ categoryName: String, isSelected: Bool) {
        if !purchaseManager.isProVersion && !selectedCategories.contains(categoryName) {
            // Free users cannot add new categories
            showingPurchaseAlert = true
            return
        }

        if isSelected {
            // Large widget can display up to 8 categories
            if selectedCategories.count < 8 {
                selectedCategories.insert(categoryName)
            }
        } else {
            selectedCategories.remove(categoryName)
        }
    }

    private func hasChanges() -> Bool {
        let currentCategories = Set(dataManager.getWidgetCategories())
        return selectedCategories != currentCategories
    }

    private func saveSettings() {
        print("🔧 WidgetCategorySettingsView.saveSettings called")
        print("🔧 Selected categories: \(selectedCategories)")
        print("🔧 Pro version: \(purchaseManager.isProVersion)")

        let sortedCategories = dataManager.categories
            .filter { selectedCategories.contains($0.name) }
            .sorted(by: { $0.order < $1.order })
            .map { $0.name }

        print("🔧 Sorted categories to save: \(sortedCategories)")

        dataManager.saveWidgetCategories(sortedCategories)
        showingSaveConfirmation = true
    }
}

struct CategorySelectionRow: View {
    let category: Category
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: category.color))
                .frame(width: 30)

            Text(category.name)
                .foregroundColor(isDisabled && !isSelected ? .secondary : .primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(isDisabled ? .secondary : .primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled || isSelected {
                onToggle(!isSelected)
            }
        }
        .opacity(isDisabled && !isSelected ? 0.6 : 1.0)
    }
}

struct ProUpgradeCard: View {
    let onTapUpgrade: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Pro版限定機能")
                        .font(.headline)
                }
                Text("widget_can_select_freely".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onTapUpgrade) {
                Text("upgrade".localized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding()
    }
}

#Preview {
    WidgetCategorySettingsView()
}
