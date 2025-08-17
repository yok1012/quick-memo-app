import SwiftUI

struct MemoListView: View {
    @StateObject private var dataManager = DataManager.shared
    let selectedCategory: String
    let searchText: String
    
    private var filteredMemos: [QuickMemo] {
        dataManager.filteredMemos(category: selectedCategory, searchText: searchText)
    }
    
    var body: some View {
        List {
            ForEach(filteredMemos, id: \.id) { memo in
                MemoRow(memo: memo)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteMemos)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            // DataManager自動更新のため何もしない
        }
    }
    
    private func deleteMemos(offsets: IndexSet) {
        withAnimation {
            let memosToDelete = offsets.map { filteredMemos[$0] }
            for memo in memosToDelete {
                dataManager.deleteMemo(id: memo.id)
            }
        }
    }
}

struct MemoRow: View {
    let memo: QuickMemo
    
    private var categoryColor: Color {
        switch memo.primaryCategory {
        case "仕事": return Color(hex: "#007AFF")
        case "プライベート": return Color(hex: "#34C759")
        case "アイデア": return Color(hex: "#FF9500")
        case "人物": return Color(hex: "#AF52DE")
        default: return Color(hex: "#8E8E93")
        }
    }
    
    private var categoryIcon: String {
        switch memo.primaryCategory {
        case "仕事": return "briefcase"
        case "プライベート": return "house"
        case "アイデア": return "lightbulb"
        case "人物": return "person"
        default: return "folder"
        }
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
                Text(memo.content)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text(memo.primaryCategory)
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

