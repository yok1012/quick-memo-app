import SwiftUI

struct MemoListView: View {
    @StateObject private var dataManager = DataManager.shared
    let selectedCategory: String
    let searchText: String
    @State private var editingMemo: QuickMemo? = nil
    
    private var filteredMemos: [QuickMemo] {
        dataManager.filteredMemos(category: selectedCategory, searchText: searchText)
    }
    
    var body: some View {
        List {
            ForEach(filteredMemos, id: \.id) { memo in
                MemoRow(memo: memo)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingMemo = memo
                    }
            }
            .onDelete(perform: deleteMemos)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            // DataManager自動更新のため何もしない
        }
        .sheet(item: $editingMemo) { memo in
            EditMemoView(memo: memo)
        }
    }
    
    private func deleteMemos(offsets: IndexSet) {
        withAnimation {
            let memosToDelete = offsets.map { filteredMemos[$0] }
            for var memo in memosToDelete {
                // カレンダーイベントも削除
                memo.deleteCalendarEvent()
                dataManager.deleteMemo(id: memo.id)
            }
        }
    }
}

struct MemoRow: View {
    let memo: QuickMemo
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var categoryColor: Color {
        let key = LocalizedCategories.baseKey(forLocalizedName: memo.primaryCategory) ?? "custom"
        switch key {
        case "work": return Color(hex: "#007AFF")
        case "personal": return Color(hex: "#34C759")
        case "idea": return Color(hex: "#FF9500")
        case "people": return Color(hex: "#AF52DE")
        case "other": return Color(hex: "#8E8E93")
        default: return Color(hex: "#8E8E93")
        }
    }

    private var categoryIcon: String {
        let key = LocalizedCategories.baseKey(forLocalizedName: memo.primaryCategory) ?? memo.primaryCategory
        return LocalizedCategories.iconName(for: key)
    }

    private var localizedCategoryName: String {
        LocalizedCategories.getLocalizedName(for: memo.primaryCategory)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .foregroundColor(categoryColor)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(categoryColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // タイトルがある場合はタイトルを表示、ない場合はコンテンツの先頭を表示
                if !memo.title.isEmpty {
                    Text(memo.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(memo.content)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(memo.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                HStack {
                    Text(localizedCategoryName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(categoryColor.opacity(0.1))
                        )
                    
                    if !memo.tags.isEmpty {
                        ForEach(Array(memo.tags.prefix(2)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        if memo.tags.count > 2 {
                            Text("+\(memo.tags.count - 2)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if memo.durationMinutes != 30 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(memo.durationMinutes) \(localizationManager.localizedString(for: "memo_minutes"))")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Text(relativeTimeString(from: memo.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
