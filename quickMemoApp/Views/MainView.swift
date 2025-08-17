import SwiftUI

struct MainView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedCategory: String = "すべて"
    @State private var showingCategorySelection = false
    @State private var showingFastInput = false
    @State private var searchText = ""
    @State private var showingCalendarPermission = false
    @State private var showingSearch = false
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear {
                checkCalendarPermission()
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView()
            }
            .sheet(isPresented: $showingFastInput) {
                FastInputView()
            }
            .sheet(isPresented: $showingCalendarPermission) {
                CalendarPermissionView()
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
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
    
}

#Preview {
    MainView()
}