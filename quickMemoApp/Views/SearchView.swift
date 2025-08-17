import SwiftUI

struct SearchView: View {
    @StateObject private var dataManager = DataManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var showingDatePicker = false
    @State private var showingTagPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                
                filterSection
                
                searchResults
            }
            .navigationTitle("検索")
            .sheet(isPresented: $showingDatePicker) {
                DateRangePickerView(startDate: $startDate, endDate: $endDate)
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerView(selectedTags: $selectedTags)
            }
        }
    }
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("メモを検索...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("クリア") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if hasActiveFilters {
                clearFiltersButton
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: .gray.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryFilterButton
                tagFilterButton
                dateFilterButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6).opacity(0.5))
    }
    
    private var categoryFilterButton: some View {
        Button(action: {
            // カテゴリフィルター処理
        }) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                Text("カテゴリ")
                if !selectedCategories.isEmpty {
                    Text("(\(selectedCategories.count))")
                        .fontWeight(.semibold)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedCategories.isEmpty ? Color(.systemGray5) : Color.blue)
            )
            .foregroundColor(selectedCategories.isEmpty ? .primary : .white)
        }
        .contextMenu {
            ForEach(dataManager.categories, id: \.id) { category in
                Button(action: {
                    toggleCategory(category.name)
                }) {
                    HStack {
                        Text(category.name)
                        if selectedCategories.contains(category.name) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    private var tagFilterButton: some View {
        Button(action: {
            showingTagPicker = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                Text("タグ")
                if !selectedTags.isEmpty {
                    Text("(\(selectedTags.count))")
                        .fontWeight(.semibold)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedTags.isEmpty ? Color(.systemGray5) : Color.blue)
            )
            .foregroundColor(selectedTags.isEmpty ? .primary : .white)
        }
    }
    
    private var dateFilterButton: some View {
        Button(action: {
            showingDatePicker = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text("日付")
                if startDate != nil || endDate != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill((startDate != nil || endDate != nil) ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor((startDate != nil || endDate != nil) ? .white : .primary)
        }
    }
    
    private var clearFiltersButton: some View {
        Button(action: {
            clearAllFilters()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                Text("フィルターをクリア")
            }
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var searchResults: some View {
        let filteredMemos = dataManager.searchMemos(
            searchText: searchText,
            categories: selectedCategories,
            tags: selectedTags,
            startDate: startDate,
            endDate: endDate
        )
        
        return List {
            ForEach(filteredMemos, id: \.id) { memo in
                MemoRow(memo: memo)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        .overlay {
            if filteredMemos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("検索結果が見つかりません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("検索条件を変更してお試しください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty || startDate != nil || endDate != nil
    }
    
    private func toggleCategory(_ categoryName: String) {
        if selectedCategories.contains(categoryName) {
            selectedCategories.remove(categoryName)
        } else {
            selectedCategories.insert(categoryName)
        }
    }
    
    private func clearAllFilters() {
        selectedCategories.removeAll()
        selectedTags.removeAll()
        startDate = nil
        endDate = nil
    }
    
}

struct DateRangePickerView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var tempStartDate = Date()
    @State private var tempEndDate = Date()
    @State private var useStartDate = false
    @State private var useEndDate = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("開始日を指定", isOn: $useStartDate)
                        .font(.headline)
                    
                    if useStartDate {
                        DatePicker("開始日", selection: $tempStartDate, displayedComponents: .date)
                            .datePickerStyle(WheelDatePickerStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("終了日を指定", isOn: $useEndDate)
                        .font(.headline)
                    
                    if useEndDate {
                        DatePicker("終了日", selection: $tempEndDate, displayedComponents: .date)
                            .datePickerStyle(WheelDatePickerStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("期間を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("適用") {
                        applyDates()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let start = startDate {
                tempStartDate = start
                useStartDate = true
            }
            if let end = endDate {
                tempEndDate = end
                useEndDate = true
            }
        }
    }
    
    private func applyDates() {
        startDate = useStartDate ? Calendar.current.startOfDay(for: tempStartDate) : nil
        endDate = useEndDate ? Calendar.current.dateInterval(of: .day, for: tempEndDate)?.end : nil
    }
}

struct TagPickerView: View {
    @Binding var selectedTags: Set<String>
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    
    private var availableTags: [String] {
        dataManager.getAllTags()
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(availableTags, id: \.self) { tag in
                    HStack {
                        Button(action: {
                            toggleTag(tag)
                        }) {
                            HStack {
                                Text("#\(tag)")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("タグを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("クリア") {
                        selectedTags.removeAll()
                    }
                    .disabled(selectedTags.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
}

#Preview {
    SearchView()
}