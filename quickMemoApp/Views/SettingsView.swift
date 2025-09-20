import SwiftUI
import EventKit

struct SettingsView: View {
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isTestingConnection = false
    @State private var showTestResult = false
    @State private var testResultMessage = ""
    @State private var testResultSuccess = false
    @State private var showingPermissionRequest = false
    @State private var showingCalendarDebug = false
    @State private var showingForceSyncAlert = false
    @State private var showingPurchase = false
    @State private var showingWidgetSettings = false
    @AppStorage("calendar_sync_mode") private var syncMode = "normal"

    var body: some View {
        NavigationStack {
            List {
                // Pro版セクション
                if !purchaseManager.isProVersion {
                    Section {
                        Button(action: {
                            showingPurchase = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text("QuickMemo Pro")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    Text("すべての機能をアンロック")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Label("アップグレード", systemImage: "star")
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Pro版をご利用中")
                                .font(.headline)
                            Spacer()
                        }
                    } header: {
                        Label("Pro版", systemImage: "star.fill")
                    }
                }
                
                // 使用状況セクション
                Section {
                    usageStatsView
                } header: {
                    Label("使用状況", systemImage: "chart.bar")
                }

                // ウィジェット設定セクション
                Section {
                    Button(action: {
                        showingWidgetSettings = true
                    }) {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(.blue)
                            Text("ウィジェットカテゴリー設定")
                            Spacer()
                            if !purchaseManager.isProVersion {
                                Text("Pro限定")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("ウィジェット", systemImage: "apps.iphone")
                } footer: {
                    Text(purchaseManager.isProVersion ? "ウィジェットに表示するカテゴリーを選択できます" : "Pro版では表示するカテゴリーをカスタマイズできます")
                        .font(.system(size: 12))
                }
                
                // カレンダー設定セクション
                Section {
                    connectionStatusView

                    if let lastError = calendarService.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text("最後のエラー")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        Text(lastError)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }

                    // アクション
                    actionButtons

                } header: {
                    Label("カレンダー連携", systemImage: "calendar")
                } footer: {
                    Text("メモをカレンダーに自動記録するための設定です。カレンダーへのフルアクセス権限が必要です。")
                        .font(.system(size: 12))
                }

                // カレンダー同期モード
                Section {
                    Picker("同期モード", selection: $syncMode) {
                        Text("通常").tag("normal")
                        Text("強制同期").tag("force")
                    }
                    .pickerStyle(.segmented)
                    
                    if syncMode == "force" {
                        Button(action: {
                            showingForceSyncAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                Text("今すぐ強制同期")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Label("同期設定", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text(syncMode == "force" ? "実機での接続問題がある場合は強制同期モードを使用してください。バッテリー消費が増加する可能性があります。" : "通常モードでは効率的な同期を行います。")
                        .font(.system(size: 12))
                }

                // 診断情報セクション
                Section {
                    diagnosticsView
                    
                    // デバッグログへのリンク
                    Button(action: {
                        showingCalendarDebug = true
                    }) {
                        HStack {
                            Image(systemName: "ladybug")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            Text("カレンダーデバッグログ")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("診断情報", systemImage: "stethoscope")
                }

                // アプリ情報セクション
                Section {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("ビルド")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("アプリ情報", systemImage: "info.circle")
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showingPermissionRequest) {
                CalendarPermissionView()
            }
            .sheet(isPresented: $showingCalendarDebug) {
                CalendarDebugView()
            }
            .sheet(isPresented: $showingPurchase) {
                PurchaseView()
            }
            .sheet(isPresented: $showingWidgetSettings) {
                WidgetCategorySettingsView()
            }
            .alert("接続テスト結果", isPresented: $showTestResult) {
                Button("OK") {
                    showTestResult = false
                }
            } message: {
                Text(testResultMessage)
            }
            .sheet(isPresented: $showingPermissionRequest) {
                CalendarPermissionView()
            }
            .sheet(isPresented: $showingCalendarDebug) {
                CalendarDebugView()
            }
            .alert("強制同期", isPresented: $showingForceSyncAlert) {
                Button("同期開始") {
                    Task {
                        await calendarService.forceCalendarSync()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("カレンダーとの同期を強制的に実行します。これにより一時的にアプリが遅くなる可能性があります。")
            }
        }
    }

    private var connectionStatusView: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16))

            Text(statusText)
                .font(.system(size: 15))

            Spacer()

            if case .checking = calendarService.connectionStatus {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch calendarService.connectionStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch calendarService.connectionStatus {
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .checking:
            return .blue
        case .error:
            return .orange
        case .unknown:
            return .gray
        }
    }

    private var statusText: String {
        switch calendarService.connectionStatus {
        case .connected:
            return "接続済み"
        case .disconnected:
            return "未接続"
        case .checking:
            return "確認中..."
        case .error(let message):
            return "エラー: \(message)"
        case .unknown:
            return "状態不明"
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 接続テストボタン
            Button(action: {
                Task {
                    await testConnection()
                }
            }) {
                HStack {
                    Image(systemName: "wifi.router")
                        .font(.system(size: 14))
                    Text("接続テスト")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .disabled(isTestingConnection || calendarService.isLoading)

            // 再接続ボタン
            Button(action: {
                Task {
                    await reconnect()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                    Text("再接続")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    if calendarService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .disabled(isTestingConnection || calendarService.isLoading)

            // 権限設定ボタン
            if !calendarService.hasCalendarAccess {
                Button(action: {
                    Task {
                        await requestPermission()
                    }
                }) {
                    HStack {
                        Image(systemName: "lock.open")
                            .font(.system(size: 14))
                        Text("カレンダーアクセスを許可")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .foregroundColor(.blue)
            }

            // システム設定を開くボタン
            Button(action: {
                openSystemSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                    Text("システム設定を開く")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var diagnosticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 権限状態
            HStack {
                Text("カレンダーアクセス")
                    .font(.system(size: 14))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: calendarService.hasCalendarAccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(calendarService.hasCalendarAccess ? .green : .red)
                        .font(.system(size: 12))
                    Text(calendarService.hasCalendarAccess ? "許可済み" : "未許可")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // iOS バージョンに応じた権限の詳細
            if #available(iOS 17.0, *) {
                HStack {
                    Text("権限レベル")
                        .font(.system(size: 14))
                    Spacer()
                    Text(authorizationStatusText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // カレンダー情報
            HStack {
                Text("Quick Memoカレンダー")
                    .font(.system(size: 14))
                Spacer()
                Text(calendarStatusText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // デバイス情報
            HStack {
                Text("iOSバージョン")
                    .font(.system(size: 14))
                Spacer()
                Text(UIDevice.current.systemVersion)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var authorizationStatusText: String {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            switch status {
            case .notDetermined:
                return "未確認"
            case .restricted:
                return "制限付き"
            case .denied:
                return "拒否"
            case .fullAccess:
                return "フルアクセス"
            case .writeOnly:
                return "書き込みのみ"
            case .authorized:
                return "許可済み"
            @unknown default:
                return "不明"
            }
        } else {
            switch status {
            case .notDetermined:
                return "未確認"
            case .restricted:
                return "制限付き"
            case .denied:
                return "拒否"
            case .authorized:
                return "許可済み"
            @unknown default:
                return "不明"
            }
        }
    }

    private var calendarStatusText: String {
        if calendarService.hasCalendarAccess {
            return "設定済み"
        } else {
            return "未設定"
        }
    }

    // MARK: - Usage Stats View

    private var usageStatsView: some View {
        VStack(spacing: 12) {
            // メモ使用状況
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("メモ数")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let remaining = DataManager.shared.getRemainingMemoCount() {
                        Text("\(DataManager.shared.memos.count)/50")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("残り \(remaining) 個")
                            .font(.caption)
                            .foregroundColor(remaining <= 10 ? .red : .secondary)
                    } else {
                        HStack {
                            Text("\(DataManager.shared.memos.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("無制限")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // カテゴリ使用状況
                VStack(alignment: .trailing, spacing: 4) {
                    Text("カテゴリ数")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let remaining = DataManager.shared.getRemainingCategoryCount() {
                        Text("\(DataManager.shared.categories.count)/3")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("残り \(remaining) 個")
                            .font(.caption)
                            .foregroundColor(remaining == 0 ? .red : .secondary)
                    } else {
                        HStack {
                            Text("無制限")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("\(DataManager.shared.categories.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            
            // 機能制限の表示
            if !purchaseManager.isProVersion {
                VStack(spacing: 8) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Pro版限定機能")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        Text("• 高度なタグ管理\n• カレンダー詳細連携\n• Deep Link機能\n• Widget カスタマイズ\n• データバックアップ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func testConnection() async {
        isTestingConnection = true
        let success = await calendarService.testCalendarConnection()

        if success {
            testResultMessage = "カレンダーへの接続が正常に確認されました。メモの記録が可能です。"
            testResultSuccess = true
        } else {
            let errorDetail = if case .error(let message) = calendarService.connectionStatus {
                message
            } else {
                "接続テストに失敗しました"
            }
            testResultMessage = "カレンダーへの接続に問題があります。\n\n\(errorDetail)"
            testResultSuccess = false
        }

        isTestingConnection = false
        showTestResult = true
    }

    private func reconnect() async {
        let success = await calendarService.reconnectCalendar()

        if success {
            testResultMessage = "カレンダーへの再接続が成功しました。"
            testResultSuccess = true
        } else {
            testResultMessage = "カレンダーへの再接続に失敗しました。システム設定でアプリの権限を確認してください。"
            testResultSuccess = false
        }

        showTestResult = true
    }

    private func requestPermission() async {
        let success = await calendarService.requestCalendarAccess()

        if !success {
            // 権限が拒否された場合は権限要求画面を表示
            showingPermissionRequest = true
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}


#Preview {
    SettingsView()
}