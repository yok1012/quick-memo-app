import SwiftUI

struct MainView: View {
    @StateObject private var dataManager = DataManager.shared
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedCategory: String = "すべて"
    @State private var showingCategorySelection = false
    @State private var showingFastInput = false
    @State private var searchText = ""
    @State private var showingCalendarPermission = false
    @State private var showingSearch = false
    @State private var showingTagManagement = false
    @State private var showingSettings = false
    @State private var showingCategoryManagement = false
    @State private var deepLinkCategory: String? = nil
    @StateObject private var calendarService = CalendarService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryTabView
                
                memoListView
                
                Spacer()
                
                addButton
            }
            .navigationTitle("Quick Memo")
            .quickInputEnabled()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingCategoryManagement = true
                        }) {
                            Image(systemName: "folder")
                        }

                        Button(action: {
                            showingTagManagement = true
                        }) {
                            Image(systemName: "tag")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                        }

                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .onAppear {
                checkCalendarPermission()
            }
            .onChange(of: deepLinkManager.pendingAction) { action in
                handleDeepLink(action)
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView()
            }
            .sheet(isPresented: $showingFastInput) {
                FastInputView(defaultCategory: deepLinkCategory)
                    .onDisappear {
                        deepLinkCategory = nil
                    }
            }
            .sheet(isPresented: $showingCalendarPermission) {
                CalendarPermissionView()
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
            }
            .sheet(isPresented: $showingTagManagement) {
                TagManagementView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView()
            }
        }
    }
    
    private var categoryTabView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                categoryTab(name: "すべて", isSelected: selectedCategory == "すべて")
                
                ForEach(dataManager.categories, id: \.id) { category in
                    categoryTab(name: category.name, isSelected: selectedCategory == category.name)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private func categoryTab(name: String, isSelected: Bool) -> some View {
        Button(action: {
            selectedCategory = name
        }) {
            Text(name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var memoListView: some View {
        MemoListView(selectedCategory: selectedCategory, searchText: searchText)
    }
    
    private var addButton: some View {
        Button(action: {
            showingFastInput = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Color.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .padding(.bottom, 34)
        .scaleEffect(1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showingFastInput = true
            }
        }
    }
    
    private func checkCalendarPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !calendarService.hasCalendarAccess {
                showingCalendarPermission = true
            }
        }
    }

    private func handleDeepLink(_ action: DeepLinkManager.DeepLinkAction?) {
        guard let action = action else { return }

        switch action {
        case .openApp:
            // アプリを開くだけ
            break
        case .addMemo(let category):
            // 指定されたカテゴリーでメモ追加画面を開く
            if dataManager.categories.contains(where: { $0.name == category }) {
                deepLinkCategory = category
                showingFastInput = true
            } else {
                // カテゴリーが存在しない場合はデフォルトで開く
                showingFastInput = true
            }
        }

        deepLinkManager.clearPendingAction()
    }
    
}

#Preview {
    MainView()
        .environmentObject(DeepLinkManager())
}