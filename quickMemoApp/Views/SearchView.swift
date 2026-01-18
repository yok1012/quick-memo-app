import SwiftUI

struct SearchView: View {
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var showingDatePicker = false
    @State private var showingTagPicker = false
    @State private var selectedDatePreset: DatePreset = .all
    @State private var selectedSortOption: SortOption = .newest
    
    // 日付プリセット
    enum DatePreset: String, CaseIterable {
        case all = "all"
        case today = "today"
        case thisWeek = "this_week"
        case thisMonth = "this_month"
        case last7Days = "last_7_days"
        case last30Days = "last_30_days"
        case custom = "custom"
        
        var localizedName: String {
            switch self {
            case .all: return LocalizationManager.shared.localizedString(for: "filter_all")
            case .today: return LocalizationManager.shared.localizedString(for: "filter_today")
            case .thisWeek: return LocalizationManager.shared.localizedString(for: "filter_this_week")
            case .thisMonth: return LocalizationManager.shared.localizedString(for: "filter_this_month")
            case .last7Days: return LocalizationManager.shared.localizedString(for: "filter_last_7_days")
            case .last30Days: return LocalizationManager.shared.localizedString(for: "filter_last_30_days")
            case .custom: return LocalizationManager.shared.localizedString(for: "filter_custom")
            }
        }
        
        func dateRange() -> (start: Date?, end: Date?) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all:
                return (nil, nil)
            case .today:
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start)
                return (start, end)
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start ?? now)
                return (start, end)
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
                let end = calendar.date(byAdding: .month, value: 1, to: start ?? now)
                return (start, end)
            case .last7Days:
                let start = calendar.date(byAdding: .day, value: -7, to: now)
                return (start, now)
            case .last30Days:
                let start = calendar.date(byAdding: .day, value: -30, to: now)
                return (start, now)
            case .custom:
                return (nil, nil)
            }
        }
    }
    
    // ソートオプション
    enum SortOption: String, CaseIterable {
        case newest = "newest"
        case oldest = "oldest"
        case alphabetical = "alphabetical"
        
        var localizedName: String {
            switch self {
            case .newest: return LocalizationManager.shared.localizedString(for: "sort_newest")
            case .oldest: return LocalizationManager.shared.localizedString(for: "sort_oldest")
            case .alphabetical: return LocalizationManager.shared.localizedString(for: "sort_alphabetical")
            }
        }
        
        var icon: String {
            switch self {
            case .newest: return "arrow.down.circle"
            case .oldest: return "arrow.up.circle"
            case .alphabetical: return "textformat.abc"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                
                smartFilterSection
                
                filterSection
                
                searchResults
            }
            .navigationTitle(localizationManager.localizedString(for: "search"))
            .sheet(isPresented: $showingDatePicker) {
                DateRangePickerView(startDate: $startDate, endDate: $endDate)
                    .onDisappear {
                        if startDate != nil || endDate != nil {
                            selectedDatePreset = .custom
                        }
                    }
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
                
                TextField(localizationManager.localizedString(for: "search_placeholder"), text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(localizationManager.localizedString(for: "clear")) {
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
    
    // MARK: - Smart Filter Section
    
    private var smartFilterSection: some View {
        VStack(spacing: 8) {
            // 日付プリセット
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([DatePreset.all, .today, .thisWeek, .thisMonth, .last7Days, .last30Days], id: \.self) { preset in
                        Button(action: {
                            selectDatePreset(preset)
                        }) {
                            Text(preset.localizedName)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedDatePreset == preset ? Color.blue : Color(.systemGray5))
                                )
                                .foregroundColor(selectedDatePreset == preset ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // ソートオプション
            HStack {
                Text(localizationManager.localizedString(for: "sort_by"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedSortOption = option
                        }) {
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.localizedName)
                                if selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedSortOption.icon)
                        Text(selectedSortOption.localizedName)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.3))
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
                Text(localizationManager.localizedString(for: "category_filter"))
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
                Text(localizationManager.localizedString(for: "tag_filter"))
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
                Text(localizationManager.localizedString(for: "date_filter"))
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
                Text(localizationManager.localizedString(for: "clear_filters"))
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
        let filteredMemos = getFilteredAndSortedMemos()
        
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
                    
                    Text(localizationManager.localizedString(for: "no_search_results"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(localizationManager.localizedString(for: "change_search_conditions"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty || startDate != nil || endDate != nil || selectedDatePreset != .all
    }
    
    // MARK: - Actions
    
    private func selectDatePreset(_ preset: DatePreset) {
        selectedDatePreset = preset
        let range = preset.dateRange()
        startDate = range.start
        endDate = range.end
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
        selectedDatePreset = .all
    }
    
    private func getFilteredAndSortedMemos() -> [QuickMemo] {
        var memos = dataManager.searchMemos(
            searchText: searchText,
            categories: selectedCategories,
            tags: selectedTags,
            startDate: startDate,
            endDate: endDate
        )
        
        // ソート適用
        switch selectedSortOption {
        case .newest:
            memos.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            memos.sort { $0.createdAt < $1.createdAt }
        case .alphabetical:
            memos.sort {
                let text0 = $0.title.isEmpty ? $0.content : $0.title
                let text1 = $1.title.isEmpty ? $1.content : $1.title
                return text0.localizedCompare(text1) == .orderedAscending
            }
        }
        
        return memos
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
    @ObservedObject private var dataManager = DataManager.shared
    
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