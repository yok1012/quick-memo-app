import Foundation
import SwiftUI
import Combine

class QuickInputManager: ObservableObject {
    static let shared = QuickInputManager()
    
    @Published var lastUsedCategory: String = LocalizedCategories.localizedName(for: "work")
    @Published var quickInputEnabled: Bool = true
    @Published var recentCategories: [String] = []

    private var lastUsedCategoryIdentifier: String = "work"
    private var recentCategoryIdentifiers: [String] = []
    private var languageObserver: NSObjectProtocol?
    
    private let userDefaults = UserDefaults.standard
    private let maxRecentCategories = 3
    
    private init() {
        loadSettings()
        setupLanguageObserver()
    }
    
    func recordCategoryUsage(_ categoryName: String) {
        let identifier = normalizeIdentifier(for: categoryName)
        lastUsedCategoryIdentifier = identifier
        lastUsedCategory = localizedName(for: identifier)

        if let index = recentCategoryIdentifiers.firstIndex(of: identifier) {
            recentCategoryIdentifiers.remove(at: index)
        }
        recentCategoryIdentifiers.insert(identifier, at: 0)
        
        if recentCategoryIdentifiers.count > maxRecentCategories {
            recentCategoryIdentifiers = Array(recentCategoryIdentifiers.prefix(maxRecentCategories))
        }

        recentCategories = recentCategoryIdentifiers.map(localizedName(for:))
        
        saveSettings()
    }
    
    func getQuickCategory() -> String {
        return lastUsedCategory
    }
    
    func preloadCategories() -> [String] {
        if recentCategories.isEmpty {
            return LocalizedCategories.defaultQuickCategoryKeys().map { LocalizedCategories.localizedName(for: $0) }
        }
        return recentCategories
    }
    
    private func loadSettings() {
        if let storedIdentifier = userDefaults.string(forKey: "lastUsedCategoryKey") {
            lastUsedCategoryIdentifier = storedIdentifier
        } else {
            // Legacy support: fallback to localized string
            let legacyName = userDefaults.string(forKey: "lastUsedCategory") ?? LocalizedCategories.localizedName(for: "work")
            lastUsedCategoryIdentifier = normalizeIdentifier(for: legacyName)
        }

        if let storedIdentifiers = userDefaults.array(forKey: "recentCategoryKeys") as? [String] {
            recentCategoryIdentifiers = storedIdentifiers
        } else {
            let legacyNames = userDefaults.array(forKey: "recentCategories") as? [String] ?? []
            recentCategoryIdentifiers = legacyNames.map(normalizeIdentifier(for:))
        }

        lastUsedCategory = localizedName(for: lastUsedCategoryIdentifier)
        recentCategories = recentCategoryIdentifiers.map(localizedName(for:))
        quickInputEnabled = userDefaults.bool(forKey: "quickInputEnabled")
    }
    
    private func saveSettings() {
        userDefaults.set(lastUsedCategoryIdentifier, forKey: "lastUsedCategoryKey")
        userDefaults.set(recentCategoryIdentifiers, forKey: "recentCategoryKeys")
        userDefaults.set(lastUsedCategory, forKey: "lastUsedCategory")
        userDefaults.set(recentCategories, forKey: "recentCategories")
        userDefaults.set(quickInputEnabled, forKey: "quickInputEnabled")
    }

    private func normalizeIdentifier(for name: String) -> String {
        LocalizedCategories.baseKey(forLocalizedName: name) ?? name
    }

    private func localizedName(for identifier: String) -> String {
        if let baseKey = LocalizedCategories.baseKey(forLocalizedName: identifier) {
            return LocalizedCategories.localizedName(for: baseKey)
        }
        return identifier
    }

    private func setupLanguageObserver() {
        languageObserver = NotificationCenter.default.addObserver(
            forName: LocalizationManager.languageDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastUsedCategory = self.localizedName(for: self.lastUsedCategoryIdentifier)
            self.recentCategories = self.recentCategoryIdentifiers.map(self.localizedName(for:))
        }
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }
}

struct QuickInputViewModifier: ViewModifier {
    @StateObject private var quickInputManager = QuickInputManager.shared
    @State private var showingQuickInput = false
    @State private var showingCategorySelection = false
    
    func body(content: Content) -> some View {
        content
            .onShake {
                if quickInputManager.quickInputEnabled {
                    showingQuickInput = true
                }
            }
            .sheet(isPresented: $showingQuickInput) {
                QuickMemoInputView()
            }
    }
}

extension View {
    func quickInputEnabled() -> some View {
        modifier(QuickInputViewModifier())
    }
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}
