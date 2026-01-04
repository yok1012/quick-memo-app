import Foundation
import SwiftUI
import WidgetKit

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    static let languageDidChangeNotification = Notification.Name("LanguageDidChange")

    @AppStorage("app_language") private var storedLanguage: String = "device"
    @Published var currentLanguage: String = ""
    @Published var refreshID = UUID()  // Force view refresh

    private let supportedLanguages = [
        "device", // Follow device settings
        "ja",     // Japanese
        "en",     // English
        "zh-Hans" // Simplified Chinese
    ]

    init() {
        // 初期化時に保存された言語を設定
        if storedLanguage == "device" || storedLanguage.isEmpty {
            // デバイス設定に従う
            followDeviceLanguage()
            // App Groupにも保存
            saveLanguageToAppGroup("device")
        } else {
            // 固定言語を使用
            currentLanguage = storedLanguage
            setLanguage(storedLanguage)
        }
    }

    private func followDeviceLanguage() {
        // システムの言語を取得
        let preferredLanguage = Locale.preferredLanguages.first ?? "ja"
        let languageCode = String(preferredLanguage.prefix(2))

        // サポートされている言語かチェック
        if languageCode == "ja" {
            currentLanguage = "ja"
        } else if languageCode == "en" {
            currentLanguage = "en"
        } else if languageCode == "zh" {
            currentLanguage = "zh-Hans"
        } else {
            currentLanguage = "en" // デフォルトは英語（国際標準）
        }

        // Bundleの言語設定を変更
        Bundle.setLanguage(currentLanguage)

        // App GroupにもdeviceモードとしてのcurrentLanguageを保存（ウィジェット用）
        saveLanguageToAppGroup(currentLanguage)

        // Force refresh
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func setLanguage(_ language: String) {
        storedLanguage = language

        if language == "device" {
            // デバイス設定に従う
            followDeviceLanguage()
        } else {
            // 固定言語を設定
            currentLanguage = language

            // UserDefaultsの言語設定を変更
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()

            // Bundleの言語設定を変更
            Bundle.setLanguage(language)
        }

        // App Group UserDefaultsにも言語設定を保存（ウィジェット用）
        saveLanguageToAppGroup(language)

        // Force all views to refresh
        DispatchQueue.main.async { [weak self] in
            self?.refreshID = UUID()
            self?.objectWillChange.send()
        }

        // Notify all observers about language change
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)

        // Update default categories with new language
        updateDefaultCategories()

        // ウィジェットを更新
        reloadWidgets()
    }

    private func saveLanguageToAppGroup(_ language: String) {
        let appGroupIdentifier = "group.yokAppDev.quickMemoApp"
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults.set(language, forKey: "app_language")
            userDefaults.synchronize()
        }
    }

    private func reloadWidgets() {
        // すべてのウィジェットのタイムラインを更新
        WidgetCenter.shared.reloadAllTimelines()
    }

    func getLanguageName(for code: String) -> String {
        switch code {
        case "device":
            return localizedString(for: "follow_device")
        case "ja":
            return "日本語"
        case "en":
            return "English"
        case "zh-Hans":
            return "中文（简体）"
        default:
            return code
        }
    }

    // Dynamic localization method
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        if arguments.isEmpty {
            return key.localized
        } else {
            return String(format: key.localized, arguments: arguments)
        }
    }

    private func updateDefaultCategories() {
        // Notify DataManager to update category names
        NotificationCenter.default.post(
            name: Notification.Name("UpdateCategoryLanguage"),
            object: nil
        )
    }
}

// Bundle拡張：動的な言語切り替えをサポート
private var bundleKey: UInt8 = 0

extension Bundle {
    class func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, AnyLanguageBundle.self)
        }

        objc_setAssociatedObject(Bundle.main, &bundleKey,
                                 Bundle.main.path(forResource: language, ofType: "lproj"),
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private class AnyLanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &bundleKey) as? String,
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }

        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// SwiftUI用のローカライズヘルパー
extension String {
    var localized: String {
        // Use dynamic bundle for runtime language switching
        guard let bundlePath = objc_getAssociatedObject(Bundle.main, &bundleKey) as? String,
              let bundle = Bundle(path: bundlePath) else {
            // Fallback to main bundle
            return NSLocalizedString(self, bundle: Bundle.main, comment: "")
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}

// デフォルトカテゴリー名のローカライズ
struct LocalizedCategories {
    private struct CategoryConfig {
        let color: String
        let icon: String
        let defaultTagKeys: [String]
        let localizedNames: [String]
    }

    private static let categoryConfigs: [String: CategoryConfig] = [
        "work": CategoryConfig(
            color: "#007AFF",
            icon: "briefcase",
            defaultTagKeys: ["meeting", "task", "deadline", "idea_tag"],
            localizedNames: ["仕事", "Work", "work", "工作"]
        ),
        "personal": CategoryConfig(
            color: "#FF6B35",
            icon: "house",
            defaultTagKeys: ["schedule", "memory", "health"],
            localizedNames: ["プライベート", "Private", "Personal", "私人", "个人", "personal"]
        ),
        "idea": CategoryConfig(
            color: "#34C759",
            icon: "lightbulb",
            defaultTagKeys: ["business", "creation", "improvement", "memo_tag"],
            localizedNames: ["アイデア", "Ideas", "Idea", "ideas", "想法"]
        ),
        "people": CategoryConfig(
            color: "#AF52DE",
            icon: "person",
            defaultTagKeys: ["contacts", "conversation", "appointment", "relationship"],
            localizedNames: ["人物", "People", "people"]
        ),
        "other": CategoryConfig(
            color: "#8E8E93",
            icon: "folder",
            defaultTagKeys: ["misc", "temp", "pending", "hold"],
            localizedNames: ["その他", "Other", "other", "其他"]
        )
    ]

    private static let defaultOrderKeys: [String] = ["work", "personal", "idea", "people"]

    static func getLocalizedName(for category: String) -> String {
        if let baseKey = baseKey(forLocalizedName: category) {
            return baseKey.localized
        }
        if categoryConfigs[category] != nil {
            return category.localized
        }
        return category
    }

    static func getDefaultCategories() -> [(key: String, name: String, color: String)] {
        defaultOrderKeys.map { key in
            (key: key, name: key.localized, color: categoryConfigs[key]?.color ?? "#8E8E93")
        }
    }

    static func localizedName(for key: String) -> String {
        key.localized
    }

    static func baseKey(forLocalizedName name: String) -> String? {
        for (key, config) in categoryConfigs {
            if config.localizedNames.contains(name) || key == name {
                return key
            }
        }
        return nil
    }

    static func allLocalizedVariants(for key: String) -> [String] {
        var variants = categoryConfigs[key]?.localizedNames ?? []
        variants.append(key)
        return Array(Set(variants))
    }

    static func colorHex(for key: String) -> String {
        categoryConfigs[key]?.color ?? "#8E8E93"
    }

    static func iconName(for key: String) -> String {
        categoryConfigs[key]?.icon ?? "folder"
    }

    static func defaultTagKeys(for key: String) -> [String] {
        categoryConfigs[key]?.defaultTagKeys ?? []
    }

    static func defaultQuickCategoryKeys() -> [String] {
        Array(defaultOrderKeys.prefix(3))
    }
}
