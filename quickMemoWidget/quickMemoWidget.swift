import WidgetKit
import SwiftUI

// String Extension for Localization
extension String {
    var localized: String {
        // Get language preference from App Group UserDefaults
        let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
        let languageCode: String

        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let savedLanguage = userDefaults.string(forKey: "app_language"),
           savedLanguage != "device" {
            languageCode = savedLanguage
        } else {
            languageCode = Locale.current.language.languageCode?.identifier ?? "ja"
        }

        // Map language codes to bundle resource names
        let resourceName: String
        switch languageCode {
        case "en":
            resourceName = "en"
        case "zh-Hans", "zh":
            resourceName = "zh-Hans"
        default:
            resourceName = "ja"
        }

        // Try to load from specific language bundle in widget's Resources folder
        if let path = Bundle.main.path(forResource: resourceName, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localizedString = NSLocalizedString(self, bundle: bundle, comment: "")
            if localizedString != self {
                return localizedString
            }
        }

        // Fallback: Try loading from main bundle directly
        let localizedString = NSLocalizedString(self, bundle: Bundle.main, comment: "")
        if localizedString != self {
            return localizedString
        }

        // Final fallback: return hardcoded translations for essential keys
        return getHardcodedLocalization(key: self, languageCode: languageCode)
    }

    private func getHardcodedLocalization(key: String, languageCode: String) -> String {
        let translations: [String: [String: String]] = [
            "work": ["ja": "仕事", "en": "Work", "zh-Hans": "工作"],
            "personal": ["ja": "プライベート", "en": "Personal", "zh-Hans": "私人"],
            "idea": ["ja": "アイデア", "en": "Ideas", "zh-Hans": "灵感"],
            "other": ["ja": "その他", "en": "Other", "zh-Hans": "其他"],
            "quick_memo": ["ja": "Quick Memo", "en": "Quick Memo", "zh-Hans": "Quick Memo"],
            "widget_open_app": ["ja": "アプリを開く", "en": "Open App", "zh-Hans": "打开应用"],
            "widget_tap_to_add_memo": ["ja": "タップしてメモを追加", "en": "Tap to add memo", "zh-Hans": "点击添加备忘录"],
            "widget_description": ["ja": "素早くメモを追加できます", "en": "Quickly add memos", "zh-Hans": "快速添加备忘录"],
            "upgrade_to_pro": ["ja": "Pro版にアップグレード", "en": "Upgrade to Pro", "zh-Hans": "升级到Pro版"]
        ]

        if let translation = translations[key]?[languageCode] {
            return translation
        } else if let jaTranslation = translations[key]?["ja"] {
            return jaTranslation
        }
        return key
    }
}

// Data Model (Widget用の軽量版)
struct Category: Codable {
    let id: UUID
    let name: String
    let icon: String
    let color: String
    let order: Int
    let defaultTags: [String]

    init(name: String, icon: String, color: String, order: Int, defaultTags: [String]) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.order = order
        self.defaultTags = defaultTags
    }

    // カスタムデコーダー：アプリ側の追加フィールド（isDefault, baseKey, hiddenTags）を無視
    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, order, defaultTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        order = try container.decode(Int.self, forKey: .order)
        defaultTags = try container.decode([String].self, forKey: .defaultTags)
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Widget Provider
struct QuickMemoProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickMemoEntry {
        QuickMemoEntry(date: Date(), categories: sampleCategories())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickMemoEntry) -> ()) {
        let entry = QuickMemoEntry(date: Date(), categories: loadCategories())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = QuickMemoEntry(date: Date(), categories: loadCategories())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func loadCategories() -> [Category] {
        let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Widget: Failed to load UserDefaults")
            return sampleCategories()
        }

        // Check if user is Pro version
        let isProVersion = userDefaults.bool(forKey: "is_pro_version") || userDefaults.bool(forKey: "isPurchased")
        print("📊 Widget: Pro version = \(isProVersion)")

        // Load selected widget categories if Pro, otherwise use default
        if isProVersion {
            if let selectedData = userDefaults.data(forKey: "widget_categories"),
               let selectedCategoryNames = try? JSONDecoder().decode([String].self, from: selectedData) {
                print("✅ Widget: Found widget_categories: \(selectedCategoryNames)")

                if let categoriesData = userDefaults.data(forKey: "categories"),
                   let allCategories = try? JSONDecoder().decode([Category].self, from: categoriesData) {
                    print("✅ Widget: Decoded \(allCategories.count) categories from UserDefaults")

                    // Return selected categories in order (up to 8 for large widget)
                    let result = selectedCategoryNames.compactMap { name in
                        allCategories.first { $0.name == name }
                    }
                    print("✅ Widget: Returning \(result.count) selected categories")
                    return Array(result.prefix(8))
                } else {
                    print("❌ Widget: Failed to decode categories from UserDefaults")
                }
            } else {
                print("⚠️ Widget: No widget_categories found for Pro user")
            }
        }

        // For free users or fallback: return default categories
        if let data = userDefaults.data(forKey: "categories"),
           let categories = try? JSONDecoder().decode([Category].self, from: data) {
            print("📋 Widget: Using default categories (free user or fallback)")
            // Return first 4 categories
            return Array(categories.prefix(4).sorted(by: { $0.order < $1.order }))
        }

        print("⚠️ Widget: Using sample categories (no data found)")
        return sampleCategories()
    }

    private func sampleCategories() -> [Category] {
        return [
            Category(name: "work".localized, icon: "briefcase", color: "#007AFF", order: 0, defaultTags: []),
            Category(name: "personal".localized, icon: "house", color: "#34C759", order: 1, defaultTags: []),
            Category(name: "idea".localized, icon: "lightbulb", color: "#FF9500", order: 2, defaultTags: []),
            Category(name: "other".localized, icon: "folder", color: "#8E8E93", order: 3, defaultTags: [])
        ]
    }
}

struct QuickMemoEntry: TimelineEntry {
    let date: Date
    let categories: [Category]
}

// Widget Views
struct QuickMemoWidgetEntryView : View {
    var entry: QuickMemoProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(categories: entry.categories)
                .containerBackground(Color(.systemBackground), for: .widget)
        case .systemMedium:
            MediumWidgetView(categories: entry.categories)
                .containerBackground(Color(.systemBackground), for: .widget)
        case .systemLarge:
            LargeWidgetView(categories: entry.categories)
                .containerBackground(Color(.systemBackground), for: .widget)
        default:
            SmallWidgetView(categories: entry.categories)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
    }
}

struct SmallWidgetView: View {
    let categories: [Category]

    private var isProVersion: Bool {
        let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return false
        }
        return userDefaults.bool(forKey: "is_pro_version") || userDefaults.bool(forKey: "isPurchased")
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .bold))
                Text("Quick Memo")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            .foregroundColor(.primary)

            if let firstCategory = categories.first {
                Link(destination: URL(string: "quickmemo://add?category=\(firstCategory.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                    HStack {
                        Image(systemName: firstCategory.icon)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: firstCategory.color))

                        Text(firstCategory.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: firstCategory.color))
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }

            // Pro版でない場合はアップグレードボタンを表示
            if !isProVersion {
                Link(destination: URL(string: "quickmemo://purchase")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("upgrade_to_pro".localized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let categories: [Category]

    // Mediumウィジェットは最大4個まで表示
    private var displayCategories: [Category] {
        Array(categories.prefix(4))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .bold))
                Text("Quick Memo")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(displayCategories, id: \.id) { category in
                    Link(destination: URL(string: "quickmemo://add?category=\(category.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: category.color))
                                .frame(width: 24)

                            Text(category.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 2)
                        }
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let categories: [Category]

    // 最大8個まで表示
    private var displayCategories: [Category] {
        Array(categories.prefix(8))
    }

    // グリッド行数
    private var gridRowCount: Int {
        (displayCategories.count + 1) / 2  // 切り上げ
    }

    // 5個以上で2列グリッドを使用
    private var useGridLayout: Bool {
        displayCategories.count >= 5
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let headerHeight: CGFloat = 28
            let footerHeight: CGFloat = 20
            let verticalPadding: CGFloat = useGridLayout ? 10 : 16
            let contentHeight = availableHeight - headerHeight - footerHeight - (verticalPadding * 2)

            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: useGridLayout ? 16 : 20, weight: .bold))
                    Text("Quick Memo")
                        .font(.system(size: useGridLayout ? 14 : 18, weight: .bold))
                    Spacer()

                    Link(destination: URL(string: "quickmemo://open")!) {
                        Text("widget_open_app".localized)
                            .font(.system(size: useGridLayout ? 11 : 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.primary)
                .frame(height: headerHeight)

                Spacer().frame(height: 8)

                if useGridLayout {
                    // 5-8項目: 2列グリッドレイアウト（スペースを埋める）
                    let spacing: CGFloat = 8
                    let rowHeight = (contentHeight - (CGFloat(gridRowCount - 1) * spacing)) / CGFloat(gridRowCount)

                    VStack(spacing: spacing) {
                        ForEach(0..<gridRowCount, id: \.self) { rowIndex in
                            HStack(spacing: spacing) {
                                ForEach(0..<2, id: \.self) { colIndex in
                                    let index = rowIndex * 2 + colIndex
                                    if index < displayCategories.count {
                                        gridCategoryButton(displayCategories[index], height: rowHeight)
                                    } else {
                                        // 空のスペースを埋める（奇数個の場合）
                                        Color.clear
                                            .frame(height: rowHeight)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // 1-4項目: 縦並びレイアウト（スペースを埋める）
                    let spacing: CGFloat = 10
                    let itemHeight = (contentHeight - (CGFloat(displayCategories.count - 1) * spacing)) / CGFloat(displayCategories.count)

                    VStack(spacing: spacing) {
                        ForEach(displayCategories, id: \.id) { category in
                            listCategoryButton(category, height: itemHeight)
                        }
                    }
                }

                Spacer().frame(height: 8)

                // フッター
                HStack {
                    Text("widget_tap_to_add_memo".localized)
                        .font(.system(size: useGridLayout ? 10 : 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: footerHeight)
            }
            .padding(verticalPadding)
        }
    }

    // グリッドレイアウト用のボタン（5-8個）
    @ViewBuilder
    private func gridCategoryButton(_ category: Category, height: CGFloat) -> some View {
        let iconSize: CGFloat = min(22, height * 0.35)
        let textSize: CGFloat = min(14, height * 0.25)

        Link(destination: URL(string: "quickmemo://add?category=\(category.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(Color(hex: category.color))
                    .frame(width: iconSize + 4)

                Text(category.name)
                    .font(.system(size: textSize, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 2)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(Color(hex: category.color))
            }
            .padding(.horizontal, 10)
            .frame(height: height)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }

    // リストレイアウト用のボタン（1-4個）
    @ViewBuilder
    private func listCategoryButton(_ category: Category, height: CGFloat) -> some View {
        let iconSize: CGFloat = min(26, height * 0.45)
        let textSize: CGFloat = min(17, height * 0.30)

        Link(destination: URL(string: "quickmemo://add?category=\(category.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(Color(hex: category.color))
                    .frame(width: iconSize + 8)

                Text(category.name)
                    .font(.system(size: textSize, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(Color(hex: category.color))
            }
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// Main Widget
@main
struct QuickMemoWidget: Widget {
    let kind: String = "QuickMemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickMemoProvider()) { entry in
            QuickMemoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("quick_memo".localized)
        .description("widget_description".localized)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// Preview
struct QuickMemoWidget_Previews: PreviewProvider {
    static var previews: some View {
        QuickMemoWidgetEntryView(entry: QuickMemoEntry(date: Date(), categories: [
            Category(name: "work".localized, icon: "briefcase", color: "#007AFF", order: 0, defaultTags: []),
            Category(name: "personal".localized, icon: "house", color: "#34C759", order: 1, defaultTags: []),
            Category(name: "idea".localized, icon: "lightbulb", color: "#FF9500", order: 2, defaultTags: []),
            Category(name: "other".localized, icon: "folder", color: "#8E8E93", order: 3, defaultTags: [])
        ]))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}