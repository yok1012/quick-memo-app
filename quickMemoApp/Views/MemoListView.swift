import SwiftUI

struct MemoListView: View {
    @ObservedObject private var dataManager = DataManager.shared
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
    @State private var showCopiedFeedback = false

    private var categoryColor: Color {
        // DataManagerからカテゴリーを検索して色を取得
        if let category = DataManager.shared.getCategory(named: memo.primaryCategory) {
            return Color(hex: category.color)
        }
        // フォールバック：デフォルトカテゴリーの色
        let key = LocalizedCategories.baseKey(forLocalizedName: memo.primaryCategory) ?? "other"
        return Color(hex: LocalizedCategories.colorHex(for: key))
    }

    private var categoryIcon: String {
        // DataManagerからカテゴリーを検索してアイコンを取得
        if let category = DataManager.shared.getCategory(named: memo.primaryCategory) {
            return category.icon
        }
        // フォールバック：デフォルトカテゴリーのアイコン
        let key = LocalizedCategories.baseKey(forLocalizedName: memo.primaryCategory) ?? "other"
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
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(memo.content)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(4)
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
        .overlay(
            Group {
                if showCopiedFeedback {
                    Text(localizationManager.localizedString(for: "copied"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.cornerRadius(8))
                        .transition(.opacity.combined(with: .scale))
                }
            }
        )
        .contextMenu {
            // プレーンテキストでコピー
            Button(action: { copyAsPlainText() }) {
                Label(localizationManager.localizedString(for: "copy_text"), systemImage: "doc.on.doc")
            }
            
            // Markdown形式でコピー
            Button(action: { copyAsMarkdown() }) {
                Label(localizationManager.localizedString(for: "copy_markdown"), systemImage: "text.badge.checkmark")
            }
            
            // メタデータ付きでコピー
            Button(action: { copyWithMetadata() }) {
                Label(localizationManager.localizedString(for: "copy_with_metadata"), systemImage: "info.circle")
            }
            
            Divider()
            
            // 共有
            ShareLink(item: memo.content) {
                Label(localizationManager.localizedString(for: "share"), systemImage: "square.and.arrow.up")
            }
        }
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Copy Functions
    
    private func copyAsPlainText() {
        let text: String
        if !memo.title.isEmpty {
            text = "\(memo.title)\n\n\(memo.content)"
        } else {
            text = memo.content
        }
        UIPasteboard.general.string = text
        showCopiedAnimation()
    }
    
    private func copyAsMarkdown() {
        var markdown = ""
        
        // タイトルがあれば見出しとして
        if !memo.title.isEmpty {
            markdown += "# \(memo.title)\n\n"
        }
        
        // コンテンツ
        markdown += memo.content
        
        // タグがあればリンク形式で
        if !memo.tags.isEmpty {
            markdown += "\n\n---\n\n"
            markdown += memo.tags.map { "#\($0)" }.joined(separator: " ")
        }
        
        UIPasteboard.general.string = markdown
        showCopiedAnimation()
    }
    
    private func copyWithMetadata() {
        var text = ""
        
        // タイトル
        if !memo.title.isEmpty {
            text += "【\(memo.title)】\n\n"
        }
        
        // コンテンツ
        text += memo.content
        
        text += "\n\n---"
        
        // カテゴリー
        text += "\n\(localizationManager.localizedString(for: "category")): \(localizedCategoryName)"
        
        // タグ
        if !memo.tags.isEmpty {
            text += "\n\(localizationManager.localizedString(for: "tags")): \(memo.tags.joined(separator: ", "))"
        }
        
        // 所要時間
        if memo.durationMinutes != 30 {
            text += "\n\(localizationManager.localizedString(for: "duration")): \(memo.durationMinutes)\(localizationManager.localizedString(for: "memo_minutes"))"
        }
        
        // 作成日時
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current
        text += "\n\(localizationManager.localizedString(for: "created_at")): \(dateFormatter.string(from: memo.createdAt))"
        
        UIPasteboard.general.string = text
        showCopiedAnimation()
    }
    
    private func showCopiedAnimation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
}
