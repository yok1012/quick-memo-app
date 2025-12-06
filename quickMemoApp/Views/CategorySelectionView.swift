import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared  // @StateObjectから@ObservedObjectに変更
    @State private var selectedCategoryName: String?
    @State private var showingMemoInput = false
    @State private var retryCount = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerView
                
                if dataManager.categories.isEmpty {
                    emptyStateView
                } else {
                    categoryGrid
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingMemoInput) {
                if let categoryName = selectedCategoryName {
                    MemoInputView(categoryName: categoryName)
                }
            }
            .onAppear {
                print("🎯 CategorySelectionView onAppear")
                print("📊 DataManager instance: \(ObjectIdentifier(dataManager))")
                print("📊 Categories count: \(dataManager.categories.count)")
                
                // カテゴリーが空の場合、診断と修復を試みる
                if dataManager.categories.isEmpty {
                    print("⚠️ CategorySelectionView: No categories found on appear")
                    dataManager.diagnoseAndRepairCategories()
                    
                    // 1秒後に再チェック
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if dataManager.categories.isEmpty {
                            print("⚠️ Still no categories after repair attempt")
                            retryCount += 1
                            if retryCount < 3 {
                                dataManager.forceReloadCategories()
                            }
                        }
                    }
                } else {
                    print("✅ CategorySelectionView: Found \(dataManager.categories.count) categories")
                    for (i, cat) in dataManager.categories.enumerated() {
                        print("  [\(i)] \(cat.name)")
                    }
                }
            }
            .onReceive(dataManager.$categories) { newCategories in
                print("📱 CategorySelectionView received categories update: \(newCategories.count) items")
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()

                Text("select_category_title".localized)
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                Color.clear.frame(width: 60)
            }

            Text("select_category_subtitle".localized)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var categoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(dataManager.categories.sorted(by: { $0.order < $1.order }), id: \.id) { category in
                CategoryButton(category: category) {
                    selectCategory(category.name)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("category_not_found".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("カテゴリーを再読み込みしています...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("リトライ回数: \(retryCount)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: {
                print("🔄 Manual reload requested")
                retryCount += 1
                // カテゴリーを強制的に再読み込み
                dataManager.forceReloadCategories()
            }) {
                Label("カテゴリーを再読み込み", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // デバッグ情報
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info:")
                    .font(.caption.bold())
                Text("DataManager ID: \(String(describing: ObjectIdentifier(dataManager)))")
                    .font(.caption2)
                Text("Categories count: \(dataManager.categories.count)")
                    .font(.caption2)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func selectCategory(_ categoryName: String) {
        selectedCategoryName = categoryName
        showingMemoInput = true
    }
}

struct CategoryButton: View {
    let category: Category
    let action: () -> Void
    @State private var isPressed = false
    
    private var categoryColor: Color {
        return Color(hex: category.color)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            VStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(categoryColor)
                
                Text(category.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if !category.defaultTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(category.defaultTags.prefix(2)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        if category.defaultTags.count > 2 {
                            Text("...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: isPressed ? categoryColor.opacity(0.3) : .gray.opacity(0.1),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(categoryColor.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    CategorySelectionView()
}