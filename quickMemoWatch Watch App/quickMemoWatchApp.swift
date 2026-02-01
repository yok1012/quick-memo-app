//
//  quickMemoWatchApp.swift
//  quickMemoWatch Watch App
//
//  Created by kiichi yokokawa on 2025/09/21.
//

import SwiftUI
import WatchConnectivity

@main
struct quickMemoWatch_Watch_AppApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(connectivityManager)
        }
    }
}
