import SwiftUI

@main
struct quickMemoWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var dataManager = WatchDataManager.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(connectivityManager)
                .environmentObject(dataManager)
        }
    }
}