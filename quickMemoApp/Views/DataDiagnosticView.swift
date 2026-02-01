import SwiftUI

/// データ保存場所の診断情報
struct StorageLocationInfo: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let categoriesCount: Int
    let memosCount: Int
    let rawCategoriesData: Data?
    let rawMemosData: Data?
    let isAccessible: Bool
    let errorMessage: String?
}

struct DataDiagnosticView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storageLocations: [StorageLocationInfo] = []
    @State private var isScanning = false
    @State private var selectedLocation: StorageLocationInfo?
    @State private var showingDataDetail = false
    @State private var recoveryResult: String?
    @State private var showingRecoveryAlert = false

    var body: some View {
        NavigationStack {
            List {
                // 現在の状態セクション
                Section("current_data_status".localized) {
                    HStack {
                        Text("categories".localized)
                        Spacer()
                        Text("\(DataManager.shared.categories.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("memos".localized)
                        Spacer()
                        Text("\(DataManager.shared.memos.count)")
                            .foregroundColor(.secondary)
                    }
                }

                // スキャン結果セクション
                Section {
                    if isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("scanning_storage".localized)
                        }
                    } else if storageLocations.isEmpty {
                        Button(action: scanAllStorageLocations) {
                            Label("scan_all_locations".localized, systemImage: "magnifyingglass")
                        }
                    } else {
                        ForEach(storageLocations) { location in
                            StorageLocationRow(location: location) {
                                selectedLocation = location
                                showingDataDetail = true
                            }
                        }
                    }
                } header: {
                    Text("storage_locations".localized)
                } footer: {
                    Text("storage_scan_description".localized)
                }

                // データ復旧セクション
                if !storageLocations.isEmpty {
                    Section("data_recovery".localized) {
                        ForEach(storageLocations.filter { $0.categoriesCount > 0 || $0.memosCount > 0 }) { location in
                            Button(action: {
                                recoverFromLocation(location)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(location.name)
                                            .foregroundColor(.primary)
                                        Text("\(location.categoriesCount) categories, \(location.memosCount) memos")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }

                        if storageLocations.filter({ $0.categoriesCount > 0 || $0.memosCount > 0 }).isEmpty {
                            Text("no_recoverable_data".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // デバッグ情報セクション
                Section("debug_info".localized) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Group ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("group.yokAppDev.quickMemoApp")
                            .font(.system(.caption, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bundle ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Bundle.main.bundleIdentifier ?? "Unknown")
                            .font(.system(.caption, design: .monospaced))
                    }

                    Button(action: {
                        DataManager.shared.resetMigrationFlag()
                        scanAllStorageLocations()
                    }) {
                        Label("reset_migration_flag".localized, systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("data_diagnostic".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: scanAllStorageLocations) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isScanning)
                }
            }
            .sheet(isPresented: $showingDataDetail) {
                if let location = selectedLocation {
                    DataDetailView(location: location)
                }
            }
            .alert("recovery_result".localized, isPresented: $showingRecoveryAlert) {
                Button("OK") { }
            } message: {
                Text(recoveryResult ?? "")
            }
            .onAppear {
                if storageLocations.isEmpty {
                    scanAllStorageLocations()
                }
            }
        }
    }

    private func scanAllStorageLocations() {
        isScanning = true
        storageLocations = []

        DispatchQueue.global(qos: .userInitiated).async {
            var locations: [StorageLocationInfo] = []

            // 1. 標準 UserDefaults
            let standardResult = checkUserDefaults(UserDefaults.standard, name: "Standard UserDefaults", location: "Library/Preferences/<BundleID>.plist")
            locations.append(standardResult)

            // 2. App Group UserDefaults
            let appGroupSuites = [
                ("group.yokAppDev.quickMemoApp", "App Group (Primary)"),
                ("yokAppDev.quickMemoApp", "Suite: yokAppDev.quickMemoApp"),
                ("com.yokAppDev.quickMemoApp", "Suite: com.yokAppDev.quickMemoApp")
            ]

            for (suiteName, displayName) in appGroupSuites {
                if let ud = UserDefaults(suiteName: suiteName) {
                    let result = checkUserDefaults(ud, name: displayName, location: "Shared/AppGroup/\(suiteName)")
                    locations.append(result)
                } else {
                    locations.append(StorageLocationInfo(
                        name: displayName,
                        location: "Shared/AppGroup/\(suiteName)",
                        categoriesCount: 0,
                        memosCount: 0,
                        rawCategoriesData: nil,
                        rawMemosData: nil,
                        isAccessible: false,
                        errorMessage: "Cannot access this location"
                    ))
                }
            }

            DispatchQueue.main.async {
                self.storageLocations = locations
                self.isScanning = false
            }
        }
    }

    private func checkUserDefaults(_ defaults: UserDefaults, name: String, location: String) -> StorageLocationInfo {
        defaults.synchronize()

        var categoriesCount = 0
        var memosCount = 0
        var rawCategoriesData: Data?
        var rawMemosData: Data?
        var errorMessage: String?

        // カテゴリーをチェック
        if let data = defaults.data(forKey: "categories") {
            rawCategoriesData = data
            do {
                let categories = try JSONDecoder().decode([Category].self, from: data)
                categoriesCount = categories.count
            } catch {
                errorMessage = "Categories decode error: \(error.localizedDescription)"
            }
        }

        // バックアップキーもチェック
        if categoriesCount == 0, let data = defaults.data(forKey: "categories_backup") {
            rawCategoriesData = data
            do {
                let categories = try JSONDecoder().decode([Category].self, from: data)
                categoriesCount = categories.count
            } catch {
                if errorMessage == nil {
                    errorMessage = "Backup decode error: \(error.localizedDescription)"
                }
            }
        }

        // メモをチェック
        if let data = defaults.data(forKey: "quick_memos") {
            rawMemosData = data
            do {
                let memos = try JSONDecoder().decode([QuickMemo].self, from: data)
                memosCount = memos.count
            } catch {
                if errorMessage == nil {
                    errorMessage = "Memos decode error: \(error.localizedDescription)"
                }
            }
        }

        return StorageLocationInfo(
            name: name,
            location: location,
            categoriesCount: categoriesCount,
            memosCount: memosCount,
            rawCategoriesData: rawCategoriesData,
            rawMemosData: rawMemosData,
            isAccessible: true,
            errorMessage: errorMessage
        )
    }

    private func recoverFromLocation(_ location: StorageLocationInfo) {
        // attemptFullDataRecovery を使用して復旧を試みる
        // DataManager の public メソッドを使用
        let result = DataManager.shared.attemptFullDataRecovery()
        let totalRecovered = result.categories + result.memos

        if totalRecovered > 0 {
            recoveryResult = String(format: NSLocalizedString("recovered_items", comment: ""), totalRecovered)
        } else {
            recoveryResult = NSLocalizedString("no_data_recovered", comment: "")
        }
        showingRecoveryAlert = true

        // 再スキャン
        scanAllStorageLocations()
    }
}

struct StorageLocationRow: View {
    let location: StorageLocationInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(location.name)
                            .font(.headline)

                        if !location.isAccessible {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Text(location.location)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let error = location.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text("\(location.categoriesCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(location.categoriesCount > 0 ? .green : .secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption)
                        Text("\(location.memosCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(location.memosCount > 0 ? .green : .secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}

struct DataDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let location: StorageLocationInfo
    @State private var categoriesPreview: [Category] = []
    @State private var memosPreview: [QuickMemo] = []

    var body: some View {
        NavigationStack {
            List {
                Section("location_info".localized) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.headline)
                        Text(location.location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !categoriesPreview.isEmpty {
                    Section("categories_found".localized + " (\(categoriesPreview.count))") {
                        ForEach(categoriesPreview) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                Text(category.name)
                                Spacer()
                                if category.isDefault {
                                    Text("default")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if !memosPreview.isEmpty {
                    Section("memos_found".localized + " (\(memosPreview.count))") {
                        ForEach(memosPreview.prefix(20)) { memo in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memo.content)
                                    .lineLimit(2)
                                HStack {
                                    Text(memo.primaryCategory)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text(memo.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if memosPreview.count > 20 {
                            Text("... and \(memosPreview.count - 20) more")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let rawData = location.rawCategoriesData {
                    Section("raw_data_categories".localized) {
                        Text("\(rawData.count) bytes")
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                if let rawData = location.rawMemosData {
                    Section("raw_data_memos".localized) {
                        Text("\(rawData.count) bytes")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("data_detail".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPreviewData()
            }
        }
    }

    private func loadPreviewData() {
        if let data = location.rawCategoriesData,
           let categories = try? JSONDecoder().decode([Category].self, from: data) {
            categoriesPreview = categories
        }

        if let data = location.rawMemosData,
           let memos = try? JSONDecoder().decode([QuickMemo].self, from: data) {
            memosPreview = memos
        }
    }
}

#Preview {
    DataDiagnosticView()
}
