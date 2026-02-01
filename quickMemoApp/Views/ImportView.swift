import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = DataManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var showingDocumentPicker = false
    @State private var importedMemos: [QuickMemo] = []
    @State private var showingPreview = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedCategory = "その他"
    @State private var isImporting = false
    @State private var showingSuccess = false
    @State private var importedCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        // インポート方法の説明
                        importInstructionsCard

                        // ファイル選択ボタン
                        filePickerButton

                        // インポートプレビュー
                        if !importedMemos.isEmpty {
                            importPreviewSection
                        }

                        // カテゴリー選択
                        if !importedMemos.isEmpty {
                            categorySelectorSection
                        }

                        // インポートボタン
                        if !importedMemos.isEmpty {
                            importButton
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView(completion: handleDocumentPicked)
            }
            .alert("import_error".localized, isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("import_success".localized, isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(String(format: "import_success_message".localized, importedCount))
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            Text("import_memos".localized)
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            // プレースホルダー
            Color.clear
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var importInstructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("import_supported_formats".localized)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                FormatRow(icon: "doc.text", format: "format_text".localized, extensions: ".txt", description: "import_format_text_desc".localized)
                FormatRow(icon: "text.badge.checkmark", format: "format_markdown".localized, extensions: ".md", description: "import_format_markdown_desc".localized)
                FormatRow(icon: "doc.badge.gearshape", format: "format_csv".localized, extensions: ".csv", description: "import_format_csv_desc".localized)
                FormatRow(icon: "curlybraces", format: "format_json".localized, extensions: ".json", description: "import_format_json_desc".localized)
            }

            Divider()

            Text("import_encoding_detection".localized)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var filePickerButton: some View {
        Button(action: {
            showingDocumentPicker = true
        }) {
            HStack {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                Text("import_select_file".localized)
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isImporting)
    }

    private var importPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.green)
                Text(String(format: "import_preview_count".localized, importedMemos.count))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("clear".localized) {
                    importedMemos = []
                }
                .font(.system(size: 14))
                .foregroundColor(.red)
            }

            ForEach(importedMemos.prefix(5)) { memo in
                ImportMemoPreviewRow(memo: memo)
            }

            if importedMemos.count > 5 {
                Text(String(format: "import_more_items".localized, importedMemos.count - 5))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var categorySelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("import_destination_category".localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dataManager.categories, id: \.id) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category.name
                        ) {
                            selectedCategory = category.name
                        }
                    }
                }
            }

            Text("import_category_note".localized)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var importButton: some View {
        Button(action: {
            performImport()
        }) {
            HStack {
                if isImporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                Text(isImporting ? "import_importing".localized : String(format: "import_count".localized, importedMemos.count))
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isImporting ? Color.gray : Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isImporting || importedMemos.isEmpty)
    }

    // MARK: - Actions

    private func handleDocumentPicked(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            loadFile(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func loadFile(from url: URL) {
        isImporting = true

        // Security-scoped resource access
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let memos = try ExportManager.shared.importMemos(from: url)
            importedMemos = memos

            // カテゴリーが「その他」のメモに選択カテゴリーを適用
            importedMemos = importedMemos.map { memo in
                if memo.primaryCategory == "その他" || memo.primaryCategory.isEmpty {
                    var updatedMemo = memo
                    updatedMemo.primaryCategory = selectedCategory
                    return updatedMemo
                }
                return memo
            }

        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isImporting = false
    }

    private func performImport() {
        isImporting = true

        // Pro版制限チェック
        let currentCount = dataManager.memos.count
        let maxMemos = purchaseManager.isProVersion ? Int.max : 100

        var memosToImport = importedMemos
        if currentCount + memosToImport.count > maxMemos {
            let allowedCount = maxMemos - currentCount
            if allowedCount > 0 {
                memosToImport = Array(memosToImport.prefix(allowedCount))
            } else {
                errorMessage = String(format: "import_limit_exceeded".localized, maxMemos)
                showingError = true
                isImporting = false
                return
            }
        }

        // メモを追加
        for memo in memosToImport {
            // 新しいIDでメモを作成
            let newMemo = QuickMemo(
                id: UUID(),
                title: memo.title,
                content: memo.content,
                primaryCategory: memo.primaryCategory,
                tags: memo.tags,
                createdAt: Date(),
                updatedAt: Date(),
                calendarEventId: nil,
                durationMinutes: memo.durationMinutes
            )
            dataManager.addMemo(newMemo)
        }

        importedCount = memosToImport.count
        isImporting = false
        showingSuccess = true
    }
}

// MARK: - Supporting Views

struct FormatRow: View {
    let icon: String
    let format: String
    let extensions: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(format)
                        .font(.system(size: 14, weight: .medium))
                    Text(extensions)
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct ImportMemoPreviewRow: View {
    let memo: QuickMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(memo.primaryCategory)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            Text(memo.content)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)

            if !memo.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(memo.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    if memo.tags.count > 3 {
                        Text("+\(memo.tags.count - 3)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: (Result<URL, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .plainText,
            .utf8PlainText,
            .commaSeparatedText,
            .json,
            UTType(filenameExtension: "md") ?? .plainText
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<URL, Error>) -> Void

        init(completion: @escaping (Result<URL, Error>) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            completion(.success(url))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // キャンセル時は何もしない
        }
    }
}

#Preview {
    ImportView()
}
