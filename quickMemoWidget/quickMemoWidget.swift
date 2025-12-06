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

        // Map language codes to bundle paths
        let bundlePath: String
        switch languageCode {
        case "en":
            bundlePath = "en.lproj"
        case "zh-Hans", "zh":
            bundlePath = "zh-Hans.lproj"
        default:
            bundlePath = "ja.lproj"
        }

        // Try to load from specific language bundle
        if let path = Bundle.main.path(forResource: bundlePath.replacingOccurrences(of: ".lproj", with: ""), ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localizedString = NSLocalizedString(self, bundle: bundle, comment: "")
            return localizedString != self ? localizedString : self
        }

        // Fallback to default localization
        return NSLocalizedString(self, comment: "")
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
            return sampleCategories()
        }

        // Check if user is Pro version
        let isProVersion = userDefaults.bool(forKey: "is_pro_version")

        // Load selected widget categories if Pro, otherwise use default
        if isProVersion,
           let selectedData = userDefaults.data(forKey: "widget_categories"),
           let selectedCategoryNames = try? JSONDecoder().decode([String].self, from: selectedData),
           let categoriesData = userDefaults.data(forKey: "categories"),
           let allCategories = try? JSONDecoder().decode([Category].self, from: categoriesData) {
            // Return selected categories in order
            return selectedCategoryNames.compactMap { name in
                allCategories.first { $0.name == name }
            }
        }

        // For free users or fallback: return default categories
        if let data = userDefaults.data(forKey: "categories"),
           let categories = try? JSONDecoder().decode([Category].self, from: data) {
            // Free users get the default categories they currently have
            let defaultNames = ["work".localized, "personal".localized, "idea".localized, "other".localized]
            return defaultNames.compactMap { name in
                categories.first { $0.name == name }
            }.prefix(4).map { $0 }
        }

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
                ForEach(categories.prefix(4), id: \.id) { category in
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

                            Spacer()
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

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .bold))
                Text("Quick Memo")
                    .font(.system(size: 18, weight: .bold))
                Spacer()

                Link(destination: URL(string: "quickmemo://open")!) {
                    Text("widget_open_app".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .foregroundColor(.primary)

            VStack(spacing: 10) {
                ForEach(categories, id: \.id) { category in
                    Link(destination: URL(string: "quickmemo://add?category=\(category.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: category.color))
                                .frame(width: 30)

                            Text(category.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: category.color))
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
            }

            Spacer()

            HStack {
                Text("widget_tap_to_add_memo".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
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