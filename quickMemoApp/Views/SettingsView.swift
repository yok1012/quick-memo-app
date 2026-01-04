import SwiftUI
import EventKit
import UniformTypeIdentifiers
import StoreKit

struct SettingsView: View {
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @StateObject private var dataManager = DataManager.shared
    @State private var isTestingConnection = false
    @State private var showTestResult = false
    @State private var testResultMessage = ""
    @State private var testResultSuccess = false
    @State private var showingPermissionRequest = false
    @State private var showingForceSyncAlert = false
    @State private var showingPurchase = false
    @State private var showingWidgetSettings = false
    @State private var showingWatchSettings = false
    @State private var showingRewardAd = false
    @State private var showingExportOptions = false
    @State private var exportFormat: ExportManager.ExportFormat = .json
    @State private var exportType: ExportManager.ExportType = .currentMemos
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @State private var showingDataDiagnostic = false
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var showingBackupResult = false
    @State private var backupResultMessage = ""
    @State private var backupInfo: (date: Date?, memosCount: Int, categoriesCount: Int, deviceID: String?)?
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @AppStorage("calendar_sync_mode") private var syncMode = "normal"
    @AppStorage("app_language") private var selectedLanguage = LocalizationManager.shared.currentLanguage

    var body: some View {
        NavigationStack {
            List {
                // アカウントセクション（iCloud状態表示）
                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloudアカウント")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("data_sync_usage".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } header: {
                    Label("settings_account".localized, systemImage: "person.circle")
                } footer: {
                    Text("settings_account_footer".localized)
                        .font(.system(size: 12))
                }

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

                        // 購入の復元ボタンを追加
                        Button(action: {
                            Task {
                                await purchaseManager.restorePurchases()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundColor(.blue)
                                Text("purchase_restore".localized)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        
                        // サブスクリプション管理（App Store）
                        Button(action: {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                    .foregroundColor(.blue)
                                Text("subscription_manage".localized)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "arrow.up.forward.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Label("settings_upgrade".localized, systemImage: "star")
                    } footer: {
                        Text("settings_restore_footer".localized)
                            .font(.system(size: 12))
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

                        // Pro版でも復元ボタンを表示（別デバイスでの復元用）
                        Button(action: {
                            Task {
                                await purchaseManager.restorePurchases()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundColor(.blue)
                                Text("settings_restore_purchases".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        
                        // サブスクリプション管理（App Store）
                        Button(action: {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key.fill")
                                    .foregroundColor(.blue)
                                Text("subscription_manage".localized)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "arrow.up.forward.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Label("settings_pro_version".localized, systemImage: "star.fill")
                    }
                }

                // リワード広告セクション（無料版ユーザーのみ表示）
                if !purchaseManager.isProVersion {
                    Section {
                        Button(action: {
                            showingRewardAd = true
                        }) {
                            HStack {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("reward_ad_title".localized)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("reward_ad_description".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                // 現在のリワード枠数を表示
                                if rewardManager.rewardMemoCount > 0 {
                                    Text("\(rewardManager.rewardMemoCount)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Label("reward_ad_section".localized, systemImage: "play.rectangle.fill")
                    } footer: {
                        Text("reward_ad_footer".localized)
                            .font(.system(size: 12))
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
                    // 現在のメモエクスポート
                    Button(action: {
                        exportType = .currentMemos
                        showingExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("settings_export_memos".localized)
                            Spacer()
                            Text("\(dataManager.memos.count)\("items_count".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(dataManager.memos.isEmpty)

                    // 削除履歴エクスポート
                    Button(action: {
                        exportType = .archivedMemos
                        showingExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                            Text("export_archive_history".localized)
                            Spacer()
                            Text("\(dataManager.archivedMemos.count)\("items_count".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(dataManager.archivedMemos.isEmpty)

                    // すべてのデータエクスポート
                    Button(action: {
                        exportType = .all
                        showingExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "archivebox")
                                .foregroundColor(.purple)
                            Text("export_all_data".localized)
                            Spacer()
                            Text("\(dataManager.memos.count + dataManager.archivedMemos.count)\("items_count".localized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(dataManager.memos.isEmpty && dataManager.archivedMemos.isEmpty)

                    // インポートボタン
                } header: {
                    Label("settings_data_management".localized, systemImage: "externaldrive")
                } footer: {
                    Text("settings_export_footer".localized)
                        .font(.system(size: 12))
                }

                // ☁️ iCloudバックアップセクション（Pro版のみ）
                if purchaseManager.isProVersion {
                    Section {
                        // バックアップ状態
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iCloudバックアップ")
                                    .font(.subheadline)
                                if let date = cloudKitManager.lastBackupDate ?? UserDefaults.standard.object(forKey: "lastCloudBackupDate") as? Date {
                                    Text("最終バックアップ: \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("no_backup".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if cloudKitManager.isSyncing || isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                switch cloudKitManager.backupStatus {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                case .failed:
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                case .noAccount:
                                    Image(systemName: "person.crop.circle.badge.xmark")
                                        .foregroundColor(.orange)
                                default:
                                    EmptyView()
                                }
                            }
                        }

                        // 今すぐバックアップ
                        Button(action: {
                            performBackup()
                        }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                    .foregroundColor(.blue)
                                Text("backup_now".localized)
                                Spacer()
                                if isBackingUp {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isBackingUp || isRestoring)

                        // iCloudから復元
                        Button(action: {
                            performRestore()
                        }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down")
                                    .foregroundColor(.blue)
                                Text("iCloudから復元")
                                Spacer()
                                if isRestoring {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isBackingUp || isRestoring)
                    } header: {
                        Label("iCloud同期", systemImage: "icloud")
                    } footer: {
                        Text("Pro版ではデータが自動的にiCloudにバックアップされます。アプリを閉じる時に自動保存されます。")
                            .font(.system(size: 12))
                    }
                }

                // 🚨 データ復元セクション
                Section {
                    // データ診断ビュー
                    Button(action: {
                        showingDataDiagnostic = true
                    }) {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("data_diagnostic_restore".localized)
                                    .foregroundColor(.primary)
                                Text("check_storage_restore".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 旧データからの復元
                    Button(action: {
                        attemptDataRecovery()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("restore_old_version_data".localized)
                                    .foregroundColor(.primary)
                                Text("if_data_lost_after_update".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                } header: {
                    Label("データの復元", systemImage: "arrow.uturn.backward.circle")
                } footer: {
                    Text("restore_after_update_description".localized)
                        .font(.system(size: 12))
                }

                // デバッグセクション（DEBUG環境のみ）
                #if DEBUG
                Section {
                    // 購入状態のリセット
                    Button(action: {
                        Task {
                            await resetPurchaseState()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                            Text("reset_purchase_status".localized)
                            Spacer()
                        }
                    }

                    // CloudKitレコードの削除
                    Button(action: {
                        Task {
                            await deleteCloudKitRecord()
                        }
                    }) {
                        HStack {
                            Image(systemName: "icloud.slash")
                                .foregroundColor(.orange)
                            Text("CloudKitレコードを削除")
                            Spacer()
                        }
                    }

                    // Pro版の切り替え（テスト用）
                    Toggle(isOn: $purchaseManager.isProVersion) {
                        HStack {
                            Image(systemName: "star.circle")
                                .foregroundColor(.purple)
                            Text("Pro版モード（テスト用）")
                        }
                    }

                    // Sandboxトランザクションのクリア
                    Button(action: {
                        Task {
                            await clearSandboxTransactions()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .foregroundColor(.blue)
                            Text("Sandboxトランザクションをクリア")
                            Spacer()
                        }
                    }

                    // デバッグ情報の表示
                    Button(action: {
                        printDebugInfo()
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.green)
                            Text("output_debug_info".localized)
                            Spacer()
                        }
                    }
                } header: {
                    Label("デバッグツール", systemImage: "hammer.circle")
                        .foregroundColor(.orange)
                } footer: {
                    Text("debug_features_description".localized)
                        .font(.caption)
                }
                #endif

                // 法的情報セクション
                Section {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.blue)
                        Link("privacy_policy".localized, destination: URL(string: "https://yok1012.github.io/quickMemoPrivacypolicy/")!)
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Link("terms_of_use".localized, destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("legal_info".localized, systemImage: "doc.plaintext")
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
            .sheet(isPresented: $showingDataDiagnostic) {
                DataDiagnosticView()
            }
            .sheet(isPresented: $showingRewardAd) {
                RewardAdView()
            }
            .alert("settings_connection_test_result".localized, isPresented: $showTestResult) {
                Button(localizationManager.localizedString(for: "ok")) {
                    showTestResult = false
                }
            } message: {
                Text(testResultMessage)
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
            .alert("iCloudバックアップ", isPresented: $showingBackupResult) {
                Button("OK") {}
            } message: {
                Text(backupResultMessage)
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

                    if purchaseManager.isProVersion {
                        HStack {
                            Text("\(dataManager.memos.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("settings_unlimited".localized)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        // 無料版: 基本枠100 + リワード枠
                        let baseLimit = 100
                        let rewardSlots = rewardManager.rewardMemoCount
                        let totalLimit = baseLimit + rewardSlots
                        let remaining = max(0, totalLimit - dataManager.memos.count)

                        Text("\(dataManager.memos.count)/\(totalLimit)")
                            .font(.title3)
                            .fontWeight(.semibold)

                        if rewardSlots > 0 {
                            Text("\("settings_remaining".localized) \(remaining) \("settings_items".localized) (\("reward_slots".localized): +\(rewardSlots))")
                                .font(.caption)
                                .foregroundColor(remaining <= 20 ? .orange : .secondary)
                        } else {
                            Text("\("settings_remaining".localized) \(remaining) \("settings_items".localized)")
                                .font(.caption)
                                .foregroundColor(remaining <= 20 ? .orange : .secondary)
                        }
                    }
                }
                
                Spacer()
                
                // カテゴリ使用状況
                VStack(alignment: .trailing, spacing: 4) {
                    Text("settings_category_count".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if purchaseManager.isProVersion {
                        HStack {
                            Text("settings_unlimited".localized)
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("\(dataManager.categories.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    } else {
                        // 無料版: 基本枠5 + リワード枠
                        let baseLimit = 5
                        let rewardSlots = rewardManager.rewardCategoryCount
                        let totalLimit = baseLimit + rewardSlots
                        let remaining = max(0, totalLimit - dataManager.categories.count)

                        Text("\(dataManager.categories.count)/\(totalLimit)")
                            .font(.title3)
                            .fontWeight(.semibold)

                        if rewardSlots > 0 {
                            Text("\("settings_remaining".localized) \(remaining) \("settings_items".localized) (\("reward_slots".localized): +\(rewardSlots))")
                                .font(.caption)
                                .foregroundColor(remaining == 0 ? .red : .secondary)
                        } else {
                            Text("\("settings_remaining".localized) \(remaining) \("settings_items".localized)")
                                .font(.caption)
                                .foregroundColor(remaining == 0 ? .red : .secondary)
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

    // MARK: - Data Recovery Functions

    private func attemptDataRecovery() {
        print("🔄 Starting manual data recovery...")

        // マイグレーションフラグをリセットして再実行
        DataManager.shared.resetMigrationFlag()

        // 全復元を試行
        let result = DataManager.shared.attemptFullDataRecovery()

        // アラートを表示
        let message: String
        if result.categories > 0 || result.memos > 0 {
            message = "復元完了:\nカテゴリー: \(result.categories)件\nメモ: \(result.memos)件"
            print("✅ Recovery successful: \(result.categories) categories, \(result.memos) memos")
        } else {
            message = "復元可能なデータが見つかりませんでした。\n\n以前のデータが標準のUserDefaultsに保存されていない可能性があります。"
            print("⚠️ No data found to recover")
        }

        // UIAlertControllerを使用してアラートを表示
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let viewController = window.rootViewController {
            let alert = UIAlertController(title: "データ復元", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
        }
    }

    private func performBackup() {
        isBackingUp = true

        Task {
            // 🚨 バックアップ前にデータの状態を確認
            let memosCount = DataManager.shared.memos.count
            let categoriesCount = DataManager.shared.categories.count

            // データが空の場合は警告して中止
            if memosCount == 0 && categoriesCount == 0 {
                await MainActor.run {
                    isBackingUp = false
                    backupResultMessage = "⚠️ バックアップするデータがありません。\n\nメモ: 0件\nカテゴリー: 0件\n\nメモまたはカテゴリーを追加してからバックアップしてください。"
                    showingBackupResult = true
                }
                return
            }

            let success = await DataManager.shared.backupToiCloud()

            // バックアップ後、実際にCloudKitにデータが保存されたか確認
            var verificationInfo: String = ""
            if success {
                if let info = await CloudKitManager.shared.getBackupInfo() {
                    verificationInfo = "\n\n【CloudKit確認】\nメモ: \(info.memosCount)件\nカテゴリー: \(info.categoriesCount)件\n日時: \(info.date?.formatted() ?? "不明")"

                    // 保存されたデータが元のデータと一致するか確認
                    if info.memosCount != memosCount || info.categoriesCount != categoriesCount {
                        verificationInfo += "\n\n⚠️ 警告: 保存されたデータ数が一致しません！\n元のメモ: \(memosCount)件, 元のカテゴリー: \(categoriesCount)件"
                    }
                } else {
                    verificationInfo = "\n\n⚠️ CloudKitからバックアップ情報を取得できませんでした"
                }
            }

            await MainActor.run {
                isBackingUp = false

                if success {
                    backupResultMessage = "バックアップが完了しました。\n\nメモ: \(memosCount)件\nカテゴリー: \(categoriesCount)件\(verificationInfo)"
                } else {
                    // CloudKitManagerからの具体的なエラーメッセージを使用
                    if let error = cloudKitManager.syncError {
                        backupResultMessage = error
                    } else {
                        backupResultMessage = "バックアップに失敗しました。\n\n設定アプリでiCloudにサインインしていることを確認してください。"
                    }
                }
                showingBackupResult = true
            }
        }
    }

    private func performRestore() {
        isRestoring = true

        Task {
            // まずバックアップの詳細診断を実行
            let diagInfo = await CloudKitManager.shared.diagnoseBackup()

            let result = await DataManager.shared.restoreFromiCloud()

            await MainActor.run {
                isRestoring = false

                if result.memos > 0 || result.categories > 0 {
                    backupResultMessage = "復元が完了しました。\n\nメモ: \(result.memos)件\nカテゴリー: \(result.categories)件"
                } else {
                    // 詳細な診断情報を表示
                    backupResultMessage = "復元可能なバックアップが見つかりませんでした。\n\n【診断結果】\n\(diagInfo)"

                    // CloudKitManagerからの具体的なエラーメッセージも追加
                    if let error = cloudKitManager.syncError {
                        backupResultMessage += "\n\n【エラー】\n\(error)"
                    }
                }
                showingBackupResult = true
            }
        }
    }

    // MARK: - Debug Functions
    #if DEBUG
    private func resetPurchaseState() async {
        print("🔧 Debug: 購入状態をリセット開始")

        // PurchaseManagerのデバッグリセット機能を使用
        await purchaseManager.debugResetPurchaseState()

        // StoreKitの更新をスキップ（購入テストを可能にする）
        purchaseManager.debugSetSkipStoreKit(true)

        // UserDefaultsから購入情報を削除
        UserDefaults.standard.removeObject(forKey: "isProVersion")
        UserDefaults.standard.removeObject(forKey: "lastTransactionID")
        UserDefaults.standard.removeObject(forKey: "debugProMode")
        UserDefaults.standard.synchronize()

        // App Groupの共有UserDefaultsもクリア
        if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp") {
            sharedDefaults.removeObject(forKey: "isPurchased")
            sharedDefaults.synchronize()
        }

        // すべての未完了トランザクションを完了としてマーク
        // （これにより次回の購入試行が可能になる）
        for await result in Transaction.unfinished {
            switch result {
            case let .verified(transaction):
                print("  - 未完了トランザクションを完了: \(transaction.id)")
                await transaction.finish()
            case let .unverified(transaction, _):
                print("  - 未検証トランザクションを完了: \(transaction.id)")
                await transaction.finish()
            }
        }

        print("✅ Debug: 購入状態リセット完了")
        print("ℹ️ Debug: StoreKit更新がスキップされています。購入テストが可能です。")
    }

    private func deleteCloudKitRecord() async {
        print("🔧 Debug: CloudKitレコード削除開始")
        await CloudKitManager.shared.clearSubscriptionStatus()
        print("✅ Debug: CloudKitレコード削除完了")
    }

    private func clearSandboxTransactions() async {
        print("🔧 Debug: Sandboxトランザクションクリア開始")

        // すべての未完了トランザクションを完了としてマーク
        for await result in Transaction.unfinished {
            switch result {
            case let .verified(transaction):
                print("  - 未完了トランザクションを完了: \(transaction.id)")
                await transaction.finish()
            case .unverified:
                break
            }
        }

        // 購入マネージャーをリセット
        await purchaseManager.restorePurchases()

        print("✅ Debug: Sandboxトランザクションクリア完了")
    }

    private func printDebugInfo() {
        print("\n========== デバッグ情報 ==========")
        print("📱 App Info:")
        print("  - Pro版: \(purchaseManager.isProVersion)")
        print("  - UserDefaults isProVersion: \(UserDefaults.standard.bool(forKey: "isProVersion"))")

        print("\n☁️ CloudKit:")
        CloudKitManager.shared.printDebugInfo()

        print("\n💰 StoreKit:")
        Task {
            print("  - 現在のエンタイトルメント:")
            for await result in Transaction.currentEntitlements {
                switch result {
                case let .verified(transaction):
                    print("    • ID: \(transaction.id)")
                    print("      Product: \(transaction.productID)")
                    print("      Date: \(transaction.purchaseDate)")
                    print("      Revoked: \(transaction.revocationDate != nil)")
                case .unverified:
                    print("    • 未検証のトランザクション")
                }
            }
        }

        print("==================================\n")
    }
    #endif

    // MARK: - Export/Import Functions

    @MainActor
    private func exportMemos() {
        isExporting = true

        do {
            let url: URL
            switch exportType {
            case .currentMemos:
                url = try ExportManager.shared.exportMemos(format: exportFormat)
            case .archivedMemos:
                url = try ExportManager.shared.exportArchivedMemos(format: exportFormat)
            case .all:
                url = try ExportManager.shared.exportAllData(format: exportFormat)
            }
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

