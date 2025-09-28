import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var isTestingConnection = false
    @State private var showTestResult = false
    @State private var testResultMessage = ""
    @State private var testResultSuccess = false
    @State private var showingPermissionRequest = false
    @State private var showingForceSyncAlert = false
    @State private var showingPurchase = false
    @State private var showingWidgetSettings = false
    @State private var showingWatchSettings = false
    @State private var showingExportOptions = false
    @State private var exportFormat: ExportManager.ExportFormat = .json
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @AppStorage("calendar_sync_mode") private var syncMode = "normal"
    @AppStorage("app_language") private var selectedLanguage = LocalizationManager.shared.currentLanguage

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
                                    Text("settings_quickmemo_pro".localized)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    Text("settings_unlock_all_features".localized)
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
                        Label("settings_upgrade".localized, systemImage: "star")
                    }
                } else {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("settings_pro_active".localized)
                                .font(.headline)
                            Spacer()
                        }
                    } header: {
                        Label("settings_pro_version".localized, systemImage: "star.fill")
                    }
                }
                
                // 使用状況セクション
                Section {
                    usageStatsView
                } header: {
                    Label("settings_usage_stats".localized, systemImage: "chart.bar")
                }

                // ウィジェット設定セクション
                Section {
                    Button(action: {
                        showingWidgetSettings = true
                    }) {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(.blue)
                            Text("settings_widget_categories".localized)
                            Spacer()
                            if !purchaseManager.isProVersion {
                                Text("settings_pro_only".localized)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("settings_widget".localized, systemImage: "apps.iphone")
                } footer: {
                    Text(purchaseManager.isProVersion ? "settings_widget_footer_pro".localized : "settings_widget_footer_free".localized)
                        .font(.system(size: 12))
                }

                // Apple Watch設定セクション
                Section {
                    Button(action: {
                        showingWatchSettings = true
                    }) {
                        HStack {
                            Image(systemName: "applewatch")
                                .foregroundColor(.blue)
                            Text("settings_apple_watch".localized)
                            Spacer()
                            if !purchaseManager.isProVersion {
                                Text("settings_pro_only".localized)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("settings_apple_watch".localized, systemImage: "applewatch")
                } footer: {
                    Text(purchaseManager.isProVersion ? "settings_watch_footer_pro".localized : "settings_watch_footer_free".localized)
                        .font(.system(size: 12))
                }

                // 通知設定セクション
                Section {
                    Toggle("settings_enable_notifications".localized, isOn: $notificationManager.isNotificationEnabled)
                        .onChange(of: notificationManager.isNotificationEnabled) { newValue in
                            if newValue {
                                notificationManager.requestPermission { granted in
                                    if !granted {
                                        notificationManager.isNotificationEnabled = false
                                    } else {
                                        notificationManager.saveSettings()
                                    }
                                }
                            } else {
                                notificationManager.saveSettings()
                            }
                        }

                        if notificationManager.isNotificationEnabled {
                            VStack {
                                HStack {
                                    Text("settings_notification_interval".localized)
                                    Spacer()
                                    Picker("", selection: $notificationManager.notificationInterval) {
                                        Text("settings_1_minute".localized).tag(1)
                                        Text("settings_3_minutes".localized).tag(3)
                                        Text("settings_15_minutes".localized).tag(15)
                                        Text("settings_30_minutes".localized).tag(30)
                                        Text("settings_1_hour".localized).tag(60)
                                        Text("settings_1_5_hours".localized).tag(90)
                                        Text("settings_2_hours".localized).tag(120)
                                        Text("settings_3_hours".localized).tag(180)
                                        Text("settings_4_hours".localized).tag(240)
                                    }
                                    .pickerStyle(.menu)
                                    .onChange(of: notificationManager.notificationInterval) { _ in
                                        notificationManager.saveSettings()
                                    }
                                }

                                Divider()

                                Toggle("settings_quiet_mode".localized, isOn: $notificationManager.isQuietModeEnabled)
                                    .onChange(of: notificationManager.isQuietModeEnabled) { _ in
                                        notificationManager.saveSettings()
                                    }

                                if notificationManager.isQuietModeEnabled {
                                    VStack {
                                        HStack {
                                            Text("settings_start_time".localized)
                                            Spacer()
                                            DatePicker("", selection: $notificationManager.quietModeStartTime, displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                                .onChange(of: notificationManager.quietModeStartTime) { _ in
                                                    notificationManager.saveSettings()
                                                }
                                        }

                                        HStack {
                                            Text("settings_end_time".localized)
                                            Spacer()
                                            DatePicker("", selection: $notificationManager.quietModeEndTime, displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                                .onChange(of: notificationManager.quietModeEndTime) { _ in
                                                    notificationManager.saveSettings()
                                                }
                                        }
                                    }
                                }
                            }

                            Divider()

                            Button(action: {
                                notificationManager.sendTestNotification()
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(.blue)
                                    Text("settings_send_test_notification".localized)
                                    Spacer()
                                }
                            }
                        }
                } header: {
                    Label("settings_memo_notifications".localized, systemImage: "bell")
                } footer: {
                    Text("settings_notifications_footer".localized)
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
                            Text("settings_last_error".localized)
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
                    Label("settings_calendar_integration".localized, systemImage: "calendar")
                } footer: {
                    Text("settings_calendar_footer".localized)
                        .font(.system(size: 12))
                }

                // 言語設定セクション
                Section {
                    Picker("select_language".localized, selection: $selectedLanguage) {
                        Text("follow_device".localized).tag("device")
                        Divider()
                        Text("language_japanese".localized).tag("ja")
                        Text("language_english".localized).tag("en")
                        Text("language_chinese".localized).tag("zh-Hans")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedLanguage) { newValue in
                        LocalizationManager.shared.setLanguage(newValue)
                        // Language changes immediately, no restart needed
                    }
                } header: {
                    Label("language_settings".localized, systemImage: "globe")
                } footer: {
                    // Language changes immediately without restart
                }

                // カレンダー同期モード
                Section {
                    Picker("settings_sync_mode".localized, selection: $syncMode) {
                        Text("settings_normal".localized).tag("normal")
                        Text("settings_force_sync".localized).tag("force")
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
                                Text("settings_force_sync_now".localized)
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Label("settings_sync_settings".localized, systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text(syncMode == "force" ? "settings_force_sync_warning".localized : "settings_normal_sync_info".localized)
                        .font(.system(size: 12))
                }

                // 診断情報セクション
                Section {
                    diagnosticsView
                    
                } header: {
                    Label("settings_diagnostics".localized, systemImage: "stethoscope")
                }

                // データ管理セクション
                Section {
                    // エクスポートボタン
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("settings_export_memos".localized)
                            Spacer()
                            Text("\(DataManager.shared.memos.count)\("items_count".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(DataManager.shared.memos.isEmpty)

                    // インポートボタン
                } header: {
                    Label("settings_data_management".localized, systemImage: "externaldrive")
                } footer: {
                    Text("settings_export_footer".localized)
                        .font(.system(size: 12))
                }

                // アプリ情報セクション
                Section {
                    HStack {
                        Text("settings_version".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("settings_build".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("settings_app_info".localized, systemImage: "info.circle")
                }
            }
            .id(localizationManager.refreshID)  // Force refresh when language changes
            .navigationTitle("settings_title".localized)
            .sheet(isPresented: $showingPermissionRequest) {
                CalendarPermissionView()
            }
            .sheet(isPresented: $showingPurchase) {
                PurchaseView()
            }
            .sheet(isPresented: $showingWidgetSettings) {
                WidgetCategorySettingsView()
            }
            .sheet(isPresented: $showingWatchSettings) {
                WatchSettingsView()
            }
            .alert("settings_connection_test_result".localized, isPresented: $showTestResult) {
                Button(localizationManager.localizedString(for: "ok")) {
                    showTestResult = false
                }
            } message: {
                Text(testResultMessage)
            }
            .sheet(isPresented: $showingPermissionRequest) {
                CalendarPermissionView()
            }
            .alert("settings_force_sync".localized, isPresented: $showingForceSyncAlert) {
                Button("settings_start_sync".localized) {
                    Task {
                        await calendarService.forceCalendarSync()
                    }
                }
                Button("cancel".localized, role: .cancel) {}
            } message: {
                Text("settings_force_sync_message".localized)
            }
            .confirmationDialog("settings_export_format".localized, isPresented: $showingExportOptions) {
                Button("settings_json_format".localized) {
                    exportFormat = .json
                    exportMemos()
                }
                Button("settings_csv_format".localized) {
                    exportFormat = .csv
                    exportMemos()
                }
                Button("cancel".localized, role: .cancel) {}
            } message: {
                Text("settings_export_select_format".localized)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("settings_export_error".localized, isPresented: $showingExportError) {
                Button(localizationManager.localizedString(for: "ok")) {}
            } message: {
                Text(exportErrorMessage)
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
            return "settings_connected".localized
        case .disconnected:
            return "settings_disconnected".localized
        case .checking:
            return "settings_checking".localized
        case .error(let message):
            return "\("settings_error".localized): \(message)"
        case .unknown:
            return "settings_status_unknown".localized
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
                    Text("settings_connection_test".localized)
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
                    Text("settings_reconnect".localized)
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
                        Text("settings_allow_calendar_access".localized)
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
                    Text("settings_open_system_settings".localized)
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
                Text("settings_calendar_access".localized)
                    .font(.system(size: 14))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: calendarService.hasCalendarAccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(calendarService.hasCalendarAccess ? .green : .red)
                        .font(.system(size: 12))
                    Text(calendarService.hasCalendarAccess ? "settings_permitted".localized : "settings_not_permitted".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // iOS バージョンに応じた権限の詳細
            if #available(iOS 17.0, *) {
                HStack {
                    Text("settings_permission_level".localized)
                        .font(.system(size: 14))
                    Spacer()
                    Text(authorizationStatusText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            // カレンダー情報
            HStack {
                Text("settings_quick_memo_calendar".localized)
                    .font(.system(size: 14))
                Spacer()
                Text(calendarStatusText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // デバイス情報
            HStack {
                Text("settings_ios_version".localized)
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
                return "settings_not_determined".localized
            case .restricted:
                return "settings_restricted".localized
            case .denied:
                return "settings_denied".localized
            case .fullAccess:
                return "settings_full_access".localized
            case .writeOnly:
                return "settings_write_only".localized
            case .authorized:
                return "settings_authorized".localized
            @unknown default:
                return "settings_unknown".localized
            }
        } else {
            switch status {
            case .notDetermined:
                return "settings_not_determined".localized
            case .restricted:
                return "settings_restricted".localized
            case .denied:
                return "settings_denied".localized
            case .authorized:
                return "settings_authorized".localized
            @unknown default:
                return "settings_unknown".localized
            }
        }
    }

    private var calendarStatusText: String {
        if calendarService.hasCalendarAccess {
            return "settings_configured".localized
        } else {
            return "settings_not_configured".localized
        }
    }

    // MARK: - Usage Stats View

    private var usageStatsView: some View {
        VStack(spacing: 12) {
            // メモ使用状況
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings_memo_count".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let remaining = DataManager.shared.getRemainingMemoCount() {
                        Text("\(DataManager.shared.memos.count)/100")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("\("settings_remaining".localized) \(remaining) \("settings_items".localized)")
                            .font(.caption)
                            .foregroundColor(remaining <= 20 ? .orange : .secondary)
                    } else {
                        HStack {
                            Text("\(DataManager.shared.memos.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("settings_unlimited".localized)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // カテゴリ使用状況
                VStack(alignment: .trailing, spacing: 4) {
                    Text("settings_category_count".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let remaining = DataManager.shared.getRemainingCategoryCount() {
                        Text("\(DataManager.shared.categories.count)/5")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("\("settings_remaining".localized) \(remaining) \("settings_items".localized)")
                            .font(.caption)
                            .foregroundColor(remaining == 0 ? .red : .secondary)
                    } else {
                        HStack {
                            Text("settings_unlimited".localized)
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
                            Text("settings_pro_features".localized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        Text("settings_pro_features_list".localized)
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
            testResultMessage = "settings_connection_test_success".localized
            testResultSuccess = true
        } else {
            let errorDetail = if case .error(let message) = calendarService.connectionStatus {
                message
            } else {
                "settings_connection_test_failed".localized
            }
            testResultMessage = "\("settings_connection_problem".localized)\n\n\(errorDetail)"
            testResultSuccess = false
        }

        isTestingConnection = false
        showTestResult = true
    }

    private func reconnect() async {
        let success = await calendarService.reconnectCalendar()

        if success {
            testResultMessage = "settings_reconnect_success".localized
            testResultSuccess = true
        } else {
            testResultMessage = "settings_reconnect_failed".localized
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

    // MARK: - Export/Import Functions

    @MainActor
    private func exportMemos() {
        isExporting = true

        do {
            let url = try ExportManager.shared.exportMemos(format: exportFormat)
            exportedFileURL = url
            showingShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
            showingExportError = true
        }

        isExporting = false
    }

}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
