import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedCategoryName: String?
    @State private var showingMemoInput = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerView
                
                categoryGrid
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingMemoInput) {
                if let categoryName = selectedCategoryName {
                    MemoInputView(categoryName: categoryName)
                }
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
                
                Text("カテゴリを選択")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                Color.clear.frame(width: 60)
            }
            
            Text("メモの種類を選んでください")
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
            ForEach(dataManager.categories, id: \.id) { category in
                CategoryButton(category: category) {
                    selectCategory(category.name)
                }
            }
        }
    }
    
    private func selectCategory(_ categoryName: String) {
        selectedCategoryName = categoryName
        showingMemoInput = true
        // dismissを削除 - シートが閉じる時に自動的にdismissされる
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