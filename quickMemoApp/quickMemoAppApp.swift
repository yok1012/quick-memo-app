//
//  quickMemoAppApp.swift
//  quickMemoApp
//
//  Created by kiichi yokokawa on 2025/08/18.
//

import SwiftUI

@main
struct quickMemoAppApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
        }
    }
}

// Deep Link Manager
class DeepLinkManager: ObservableObject {
    @Published var pendingAction: DeepLinkAction?

    enum DeepLinkAction: Equatable {
        case openApp
        case addMemo(category: String)
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "quickmemo" else { return }

        switch url.host {
        case "open":
            pendingAction = .openApp
        case "add":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let categoryItem = components.queryItems?.first(where: { $0.name == "category" }),
               let categoryName = categoryItem.value?.removingPercentEncoding {
                pendingAction = .addMemo(category: categoryName)
            }
        default:
            break
        }
    }

    func clearPendingAction() {
        pendingAction = nil
    }
}
