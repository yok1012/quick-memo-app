import SwiftUI

struct MainView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedCategory: String = "category_all".localized
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
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingPurchase = false
    @State private var showingLimitAlert = false
    @State private var limitAlertMessage = ""
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryTabView

                memoListView

                Spacer()

                addButton
            }
            .id(localizationManager.refreshID)
            .navigationTitle("app_name".localized)
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
                        // Pro badge if not purchased
                        if !purchaseManager.isProVersion {
                            Button(action: {
                                showingPurchase = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("Pro")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
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
                setupNotificationObservers()
            }
            .onChange(of: deepLinkManager.pendingAction) { action in
                handleDeepLink(action)
            }
            .onChange(of: deepLinkManager.showPurchaseView) { show in
                if show {
                    showingPurchase = true
                    deepLinkManager.showPurchaseView = false
                }
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView()
            }
            .sheet(isPresented: $showingFastInput) {
                // deepLinkCategoryがある場合はそれを使用、なければ現在選択中のカテゴリーを使用
                let category = deepLinkCategory ?? (selectedCategory != "category_all".localized ? selectedCategory : nil)
                FastInputView(defaultCategory: category)
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
            .sheet(isPresented: $showingPurchase) {
                PurchaseView()
            }
            .alert("limit_reached".localized, isPresented: $showingLimitAlert) {
                Button("pro_purchase".localized) {
                    showingPurchase = true
                }
                Button("cancel".localized, role: .cancel) { }
            } message: {
                Text(limitAlertMessage)
            }
        }
    }
    
    private var categoryTabView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                categoryTab(name: "category_all".localized, isSelected: selectedCategory == "category_all".localized)
                
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
            // Check if user can add more memos
            if dataManager.canAddMemo() {
                showingFastInput = true
            } else {
                if let remaining = dataManager.getRemainingMemoCount() {
                    limitAlertMessage = "memo_limit_message".localized
                } else {
                    limitAlertMessage = "memo_limit_message".localized
                }
                showingLimitAlert = true
            }
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
        case .showPurchase:
            showingPurchase = true
        case .showSettings:
            showingSettings = true
        }

        deepLinkManager.clearPendingAction()
    }

    private func setupNotificationObservers() {
        // Apple Watchからの購入画面表示要求を受信
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenPurchaseView"),
            object: nil,
            queue: .main
        ) { _ in
            showingPurchase = true
        }

        // Apple Watchからの設定画面表示要求を受信
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenSettingsView"),
            object: nil,
            queue: .main
        ) { _ in
            showingSettings = true
        }
    }
    
}

#Preview {
    MainView()
        .environmentObject(DeepLinkManager())
}