import SwiftUI
import WatchKit

struct WatchMemoListView: View {
    @StateObject private var dataManager = WatchDataManager.shared
    @State private var selectedCategory: String = "すべて"

    var filteredMemos: [WatchMemo] {
        if selectedCategory == "すべて" {
            return dataManager.memos.sorted { $0.createdAt > $1.createdAt }
        } else {
            return dataManager.memos.filter { $0.category == selectedCategory }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // カテゴリー選択
                categoryPicker

                Divider()

                // メモ一覧
                if filteredMemos.isEmpty {
                    emptyView
                } else {
                    List(filteredMemos) { memo in
                        MemoRowView(memo: memo)
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("メモ一覧")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    name: "すべて",
                    isSelected: selectedCategory == "すべて",
                    color: Color.blue
                ) {
                    selectedCategory = "すべて"
                }

                ForEach(dataManager.categories) { category in
                    CategoryChip(
                        name: category.name,
                        isSelected: selectedCategory == category.name,
                        color: Color(hex: category.color)
                    ) {
                        selectedCategory = category.name
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 30))
                .foregroundColor(.secondary)

            Text("メモがありません")
                .font(.caption)
                .foregroundColor(.secondary)

            if selectedCategory != "すべて" {
                Text("\(selectedCategory)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.2))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MemoRowView: View {
    let memo: WatchMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(memo.category)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Text(memo.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !memo.title.isEmpty {
                Text(memo.title)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Text(memo.content)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
        )
    }
}

// Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    WatchMemoListView()
}