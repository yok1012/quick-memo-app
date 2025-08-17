import Foundation
import SwiftUI
import Combine

class QuickInputManager: ObservableObject {
    static let shared = QuickInputManager()
    
    @Published var lastUsedCategory: String = "仕事"
    @Published var quickInputEnabled: Bool = true
    @Published var recentCategories: [String] = []
    
    private let userDefaults = UserDefaults.standard
    private let maxRecentCategories = 3
    
    private init() {
        loadSettings()
    }
    
    func recordCategoryUsage(_ categoryName: String) {
        lastUsedCategory = categoryName
        
        if let index = recentCategories.firstIndex(of: categoryName) {
            recentCategories.remove(at: index)
        }
        recentCategories.insert(categoryName, at: 0)
        
        if recentCategories.count > maxRecentCategories {
            recentCategories = Array(recentCategories.prefix(maxRecentCategories))
        }
        
        saveSettings()
    }
    
    func getQuickCategory() -> String {
        return lastUsedCategory
    }
    
    func preloadCategories() -> [String] {
        return recentCategories.isEmpty ? ["仕事", "プライベート", "アイデア"] : recentCategories
    }
    
    private func loadSettings() {
        lastUsedCategory = userDefaults.string(forKey: "lastUsedCategory") ?? "仕事"
        recentCategories = userDefaults.array(forKey: "recentCategories") as? [String] ?? []
        quickInputEnabled = userDefaults.bool(forKey: "quickInputEnabled")
    }
    
    private func saveSettings() {
        userDefaults.set(lastUsedCategory, forKey: "lastUsedCategory")
        userDefaults.set(recentCategories, forKey: "recentCategories")
        userDefaults.set(quickInputEnabled, forKey: "quickInputEnabled")
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