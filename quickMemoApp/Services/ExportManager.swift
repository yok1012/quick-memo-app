import Foundation
import SwiftUI

class ExportManager {
    static let shared = ExportManager()

    private init() {}

    enum ExportFormat {
        case csv
        case json
        case markdown
        case plainText
    }

    enum ExportType {
        case currentMemos
        case archivedMemos
        case all
    }

    enum ExportError: LocalizedError {
        case noData
        case encodingError
        case fileCreationError

        var errorDescription: String? {
            switch self {
            case .noData:
                return "エクスポートするメモがありません"
            case .encodingError:
                return "データのエンコードに失敗しました"
            case .fileCreationError:
                return "ファイルの作成に失敗しました"
            }
        }
    }

    @MainActor
    func exportMemos(format: ExportFormat, memos: [QuickMemo]? = nil) throws -> URL {
        let memosToExport = memos ?? DataManager.shared.memos

        guard !memosToExport.isEmpty else {
            throw ExportError.noData
        }

        let fileName: String
        let fileData: Data

        switch format {
        case .csv:
            fileName = "QuickMemo_\(dateString()).csv"
            fileData = try createCSVData(from: memosToExport)
        case .json:
            fileName = "QuickMemo_\(dateString()).json"
            fileData = try createJSONData(from: memosToExport)
        case .markdown:
            fileName = "QuickMemo_\(dateString()).md"
            fileData = try createMarkdownData(from: memosToExport)
        case .plainText:
            fileName = "QuickMemo_\(dateString()).txt"
            fileData = try createPlainTextData(from: memosToExport)
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try fileData.write(to: fileURL)
            return fileURL
        } catch {
            throw ExportError.fileCreationError
        }
    }

    /// 単一メモをエクスポート（Dataを返す）
    func exportSingleMemo(_ memo: QuickMemo, format: ExportFormat) throws -> Data {
        switch format {
        case .csv:
            return try createCSVData(from: [memo])
        case .json:
            return try createJSONData(from: [memo])
        case .markdown:
            return try createMarkdownData(from: [memo])
        case .plainText:
            return try createPlainTextData(from: [memo])
        }
    }

    @MainActor
    func exportArchivedMemos(format: ExportFormat) throws -> URL {
        let archivedMemos = DataManager.shared.archivedMemos

        guard !archivedMemos.isEmpty else {
            throw ExportError.noData
        }

        // アーカイブからメモを抽出
        let memosToExport = archivedMemos.map { $0.originalMemo }

        let fileName: String
        let fileData: Data

        switch format {
        case .csv:
            fileName = "QuickMemo_Archive_\(dateString()).csv"
            fileData = try createArchivedCSVData(from: archivedMemos)
        case .json:
            fileName = "QuickMemo_Archive_\(dateString()).json"
            fileData = try createArchivedJSONData(from: archivedMemos)
        case .markdown:
            fileName = "QuickMemo_Archive_\(dateString()).md"
            fileData = try createMarkdownData(from: memosToExport)
        case .plainText:
            fileName = "QuickMemo_Archive_\(dateString()).txt"
            fileData = try createPlainTextData(from: memosToExport)
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try fileData.write(to: fileURL)
            return fileURL
        } catch {
            throw ExportError.fileCreationError
        }
    }

    @MainActor
    func exportAllData(format: ExportFormat) throws -> URL {
        let currentMemos = DataManager.shared.memos
        let archivedMemos = DataManager.shared.archivedMemos

        guard !currentMemos.isEmpty || !archivedMemos.isEmpty else {
            throw ExportError.noData
        }

        let fileName: String
        let fileData: Data

        switch format {
        case .csv:
            fileName = "QuickMemo_All_\(dateString()).csv"
            fileData = try createAllDataCSV(currentMemos: currentMemos, archivedMemos: archivedMemos)
        case .json:
            fileName = "QuickMemo_All_\(dateString()).json"
            fileData = try createAllDataJSON(currentMemos: currentMemos, archivedMemos: archivedMemos)
        case .markdown:
            fileName = "QuickMemo_All_\(dateString()).md"
            fileData = try createAllDataMarkdown(currentMemos: currentMemos, archivedMemos: archivedMemos)
        case .plainText:
            fileName = "QuickMemo_All_\(dateString()).txt"
            fileData = try createAllDataPlainText(currentMemos: currentMemos, archivedMemos: archivedMemos)
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try fileData.write(to: fileURL)
            return fileURL
        } catch {
            throw ExportError.fileCreationError
        }
    }

    private func createCSVData(from memos: [QuickMemo]) throws -> Data {
        // UTF-8 BOMを追加（Excelで日本語を正しく表示するため）
        var csvData = Data([0xEF, 0xBB, 0xBF])

        var csvString = "ID,タイトル,内容,カテゴリー,タグ,作成日時,更新日時,カレンダーイベントID,期間(分)\n"

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for memo in memos {
            let title = escapeCSVField(memo.title)
            let content = escapeCSVField(memo.content)
            let category = escapeCSVField(memo.primaryCategory)
            let tags = memo.tags.joined(separator: ";")
            let createdAt = dateFormatter.string(from: memo.createdAt)
            let updatedAt = dateFormatter.string(from: memo.updatedAt)
            let calendarEventId = memo.calendarEventId ?? ""
            let duration = String(memo.durationMinutes)

            csvString += "\(memo.id),\(title),\(content),\(category),\(tags),\(createdAt),\(updatedAt),\(calendarEventId),\(duration)\n"
        }

        guard let stringData = csvString.data(using: .utf8) else {
            throw ExportError.encodingError
        }

        csvData.append(stringData)
        return csvData
    }

    private func createJSONData(from memos: [QuickMemo]) throws -> Data {
        let exportData = ExportData(
            exportDate: Date(),
            version: "1.0",
            memos: memos.map { memo in
                ExportMemo(
                    id: memo.id.uuidString,
                    title: memo.title,
                    content: memo.content,
                    category: memo.primaryCategory,
                    tags: memo.tags,
                    timestamp: memo.createdAt,
                    lastModified: memo.updatedAt,
                    calendarEventId: memo.calendarEventId,
                    durationMinutes: memo.durationMinutes
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(exportData)
        } catch {
            throw ExportError.encodingError
        }
    }

    // MARK: - Markdown Export

    private func createMarkdownData(from memos: [QuickMemo]) throws -> Data {
        var markdown = "# QuickMemo Export\n\n"
        markdown += "> Exported on \(formattedDate(Date()))\n\n"
        markdown += "---\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for memo in memos {
            // メモタイトル（内容の最初の行または最初の30文字）
            let title = memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title
            markdown += "## \(title)\n\n"

            // メタデータ
            markdown += "- **カテゴリー**: \(memo.primaryCategory)\n"
            if !memo.tags.isEmpty {
                markdown += "- **タグ**: \(memo.tags.joined(separator: ", "))\n"
            }
            markdown += "- **作成日時**: \(dateFormatter.string(from: memo.createdAt))\n"
            markdown += "- **更新日時**: \(dateFormatter.string(from: memo.updatedAt))\n"
            markdown += "\n"

            // 本文
            markdown += "### 内容\n\n"
            markdown += "\(memo.content)\n\n"
            markdown += "---\n\n"
        }

        guard let data = markdown.data(using: .utf8) else {
            throw ExportError.encodingError
        }
        return data
    }

    // MARK: - Plain Text Export

    private func createPlainTextData(from memos: [QuickMemo]) throws -> Data {
        var text = "QuickMemo Export\n"
        text += "================\n"
        text += "Exported: \(formattedDate(Date()))\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for (index, memo) in memos.enumerated() {
            text += "[\(index + 1)] "
            let title = memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title
            text += "\(title)\n"
            text += "----------------------------------------\n"
            text += "カテゴリー: \(memo.primaryCategory)\n"
            if !memo.tags.isEmpty {
                text += "タグ: \(memo.tags.joined(separator: ", "))\n"
            }
            text += "作成日時: \(dateFormatter.string(from: memo.createdAt))\n"
            text += "\n"
            text += "\(memo.content)\n"
            text += "\n========================================\n\n"
        }

        guard let data = text.data(using: .utf8) else {
            throw ExportError.encodingError
        }
        return data
    }

    private func createAllDataMarkdown(currentMemos: [QuickMemo], archivedMemos: [ArchivedMemo]) throws -> Data {
        var markdown = "# QuickMemo Complete Export\n\n"
        markdown += "> Exported on \(formattedDate(Date()))\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        // 現在のメモ
        if !currentMemos.isEmpty {
            markdown += "## 現在のメモ (\(currentMemos.count)件)\n\n"
            markdown += "---\n\n"
            for memo in currentMemos {
                let title = memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title
                markdown += "### \(title)\n\n"
                markdown += "- **カテゴリー**: \(memo.primaryCategory)\n"
                if !memo.tags.isEmpty {
                    markdown += "- **タグ**: \(memo.tags.joined(separator: ", "))\n"
                }
                markdown += "- **作成日時**: \(dateFormatter.string(from: memo.createdAt))\n"
                markdown += "\n\(memo.content)\n\n---\n\n"
            }
        }

        // アーカイブメモ
        if !archivedMemos.isEmpty {
            markdown += "## アーカイブメモ (\(archivedMemos.count)件)\n\n"
            markdown += "---\n\n"
            for archived in archivedMemos {
                let memo = archived.originalMemo
                let title = memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title
                markdown += "### \(title)\n\n"
                markdown += "- **カテゴリー**: \(memo.primaryCategory)\n"
                if !memo.tags.isEmpty {
                    markdown += "- **タグ**: \(memo.tags.joined(separator: ", "))\n"
                }
                markdown += "- **作成日時**: \(dateFormatter.string(from: memo.createdAt))\n"
                markdown += "- **削除日時**: \(dateFormatter.string(from: archived.deletedAt))\n"
                markdown += "\n\(memo.content)\n\n---\n\n"
            }
        }

        guard let data = markdown.data(using: .utf8) else {
            throw ExportError.encodingError
        }
        return data
    }

    private func createAllDataPlainText(currentMemos: [QuickMemo], archivedMemos: [ArchivedMemo]) throws -> Data {
        var text = "QuickMemo Complete Export\n"
        text += "=========================\n"
        text += "Exported: \(formattedDate(Date()))\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        // 現在のメモ
        if !currentMemos.isEmpty {
            text += "【現在のメモ】(\(currentMemos.count)件)\n"
            text += "========================================\n\n"
            for (index, memo) in currentMemos.enumerated() {
                text += "[\(index + 1)] "
                let title = memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title
                text += "\(title)\n"
                text += "----------------------------------------\n"
                text += "カテゴリー: \(memo.primaryCategory)\n"
                if !memo.tags.isEmpty {
                    text += "タグ: \(memo.tags.joined(separator: ", "))\n"
                }
                text += "作成日時: \(dateFormatter.string(from: memo.createdAt))\n\n"
                text += "\(memo.content)\n"
                text += "\n========================================\n\n"
            }
        }

        // アーカイブメモ
        if !archivedMemos.isEmpty {
            text += "【アーカイブメモ】(\(archivedMemos.count)件)\n"
            text += "========================================\n\n"
            for (index, archived) in archivedMemos.enumerated() {
                let memo = archived.originalMemo
                text += "[\(index + 1)] "
                let title = memo.title.isEmpty ? String(memo.content.prefix(30)) : memo.title
                text += "\(title)\n"
                text += "----------------------------------------\n"
                text += "カテゴリー: \(memo.primaryCategory)\n"
                if !memo.tags.isEmpty {
                    text += "タグ: \(memo.tags.joined(separator: ", "))\n"
                }
                text += "作成日時: \(dateFormatter.string(from: memo.createdAt))\n"
                text += "削除日時: \(dateFormatter.string(from: archived.deletedAt))\n\n"
                text += "\(memo.content)\n"
                text += "\n========================================\n\n"
            }
        }

        guard let data = text.data(using: .utf8) else {
            throw ExportError.encodingError
        }
        return data
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func escapeCSVField(_ field: String) -> String {
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n")
        if needsQuotes {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private func createArchivedCSVData(from archivedMemos: [ArchivedMemo]) throws -> Data {
        // UTF-8 BOMを追加（Excelで日本語を正しく表示するため）
        var csvData = Data([0xEF, 0xBB, 0xBF])

        var csvString = "ID,タイトル,内容,カテゴリー,タグ,作成日時,更新日時,削除日時,カレンダーイベントID,期間(分)\n"

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for archived in archivedMemos {
            let memo = archived.originalMemo
            let title = escapeCSVField(memo.title)
            let content = escapeCSVField(memo.content)
            let category = escapeCSVField(memo.primaryCategory)
            let tags = memo.tags.joined(separator: ";")
            let createdAt = dateFormatter.string(from: memo.createdAt)
            let updatedAt = dateFormatter.string(from: memo.updatedAt)
            let deletedAt = dateFormatter.string(from: archived.deletedAt)
            let calendarEventId = memo.calendarEventId ?? ""
            let duration = String(memo.durationMinutes)

            csvString += "\(memo.id),\(title),\(content),\(category),\(tags),\(createdAt),\(updatedAt),\(deletedAt),\(calendarEventId),\(duration)\n"
        }

        guard let stringData = csvString.data(using: .utf8) else {
            throw ExportError.encodingError
        }

        csvData.append(stringData)
        return csvData
    }

    private func createArchivedJSONData(from archivedMemos: [ArchivedMemo]) throws -> Data {
        let exportData = ArchivedExportData(
            exportDate: Date(),
            version: "1.0",
            archivedMemos: archivedMemos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(exportData)
        } catch {
            throw ExportError.encodingError
        }
    }

    private func createAllDataCSV(currentMemos: [QuickMemo], archivedMemos: [ArchivedMemo]) throws -> Data {
        // UTF-8 BOMを追加
        var csvData = Data([0xEF, 0xBB, 0xBF])

        var csvString = "Type,ID,タイトル,内容,カテゴリー,タグ,作成日時,更新日時,削除日時,カレンダーイベントID,期間(分)\n"

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 現在のメモ
        for memo in currentMemos {
            let title = escapeCSVField(memo.title)
            let content = escapeCSVField(memo.content)
            let category = escapeCSVField(memo.primaryCategory)
            let tags = memo.tags.joined(separator: ";")
            let createdAt = dateFormatter.string(from: memo.createdAt)
            let updatedAt = dateFormatter.string(from: memo.updatedAt)
            let calendarEventId = memo.calendarEventId ?? ""
            let duration = String(memo.durationMinutes)

            csvString += "Current,\(memo.id),\(title),\(content),\(category),\(tags),\(createdAt),\(updatedAt),,\(calendarEventId),\(duration)\n"
        }

        // アーカイブメモ
        for archived in archivedMemos {
            let memo = archived.originalMemo
            let title = escapeCSVField(memo.title)
            let content = escapeCSVField(memo.content)
            let category = escapeCSVField(memo.primaryCategory)
            let tags = memo.tags.joined(separator: ";")
            let createdAt = dateFormatter.string(from: memo.createdAt)
            let updatedAt = dateFormatter.string(from: memo.updatedAt)
            let deletedAt = dateFormatter.string(from: archived.deletedAt)
            let calendarEventId = memo.calendarEventId ?? ""
            let duration = String(memo.durationMinutes)

            csvString += "Archived,\(memo.id),\(title),\(content),\(category),\(tags),\(createdAt),\(updatedAt),\(deletedAt),\(calendarEventId),\(duration)\n"
        }

        guard let stringData = csvString.data(using: .utf8) else {
            throw ExportError.encodingError
        }

        csvData.append(stringData)
        return csvData
    }

    private func createAllDataJSON(currentMemos: [QuickMemo], archivedMemos: [ArchivedMemo]) throws -> Data {
        let exportData = AllDataExport(
            exportDate: Date(),
            version: "1.0",
            currentMemos: currentMemos,
            archivedMemos: archivedMemos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(exportData)
        } catch {
            throw ExportError.encodingError
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    func importMemos(from url: URL) throws -> [QuickMemo] {
        let data = try Data(contentsOf: url)
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "json":
            return try importJSONData(data)
        case "csv":
            return try importCSVData(data)
        case "md", "markdown":
            return try importMarkdownData(data)
        case "txt", "text":
            return try importTextData(data)
        default:
            // Try to import as plain text
            return try importTextData(data)
        }
    }

    // MARK: - Text/Markdown Import

    /// テキストファイルを複数のエンコーディングで読み取り
    private func decodeTextData(_ data: Data) throws -> String {
        // UTF-8 BOMチェック
        if data.count >= 3 {
            let bom = [UInt8](data.prefix(3))
            if bom == [0xEF, 0xBB, 0xBF] {
                let textData = data.dropFirst(3)
                if let text = String(data: Data(textData), encoding: .utf8) {
                    return text
                }
            }
        }

        // 複数のエンコーディングを試行
        let encodings: [String.Encoding] = [
            .utf8,
            .shiftJIS,
            .japaneseEUC,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian,
            .isoLatin1
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        throw ExportError.encodingError
    }

    private func importTextData(_ data: Data) throws -> [QuickMemo] {
        let text = try decodeTextData(data)

        // 空のテキストはエラー
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.noData
        }

        // テキスト全体を1つのメモとしてインポート
        let memo = QuickMemo(
            content: text.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryCategory: "その他",
            tags: []
        )
        return [memo]
    }

    private func importMarkdownData(_ data: Data) throws -> [QuickMemo] {
        let text = try decodeTextData(data)

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.noData
        }

        var memos: [QuickMemo] = []

        // Markdownセクション（##で始まる）で分割
        let sections = text.components(separatedBy: "\n## ")

        for (index, section) in sections.enumerated() {
            var sectionText = section
            // 最初のセクションは#で始まる可能性がある
            if index == 0 {
                // # で始まるメインタイトルをスキップ
                if sectionText.hasPrefix("# ") {
                    let lines = sectionText.components(separatedBy: "\n")
                    if lines.count > 1 {
                        sectionText = lines.dropFirst().joined(separator: "\n")
                    } else {
                        continue
                    }
                }
                // エクスポートヘッダー部分をスキップ
                if sectionText.contains("Exported on") || sectionText.isEmpty {
                    continue
                }
            }

            let trimmed = sectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "---" {
                continue
            }

            // セクションをパース
            let parsedMemo = parseMarkdownSection("## " + sectionText)
            if let memo = parsedMemo {
                memos.append(memo)
            }
        }

        // セクションが見つからない場合、全体を1つのメモとしてインポート
        if memos.isEmpty {
            let memo = QuickMemo(
                content: text.trimmingCharacters(in: .whitespacesAndNewlines),
                primaryCategory: "その他",
                tags: []
            )
            memos.append(memo)
        }

        return memos
    }

    private func parseMarkdownSection(_ section: String) -> QuickMemo? {
        let lines = section.components(separatedBy: "\n")
        guard !lines.isEmpty else { return nil }

        var title = ""
        var category = "その他"
        var tags: [String] = []
        var contentLines: [String] = []
        var inContent = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.hasPrefix("## ") {
                // タイトル
                title = String(trimmedLine.dropFirst(3))
            } else if trimmedLine.hasPrefix("### 内容") {
                inContent = true
            } else if trimmedLine.hasPrefix("- **カテゴリー**:") || trimmedLine.hasPrefix("- **カテゴリー**：") {
                let parts = trimmedLine.components(separatedBy: ":")
                if parts.count > 1 {
                    category = parts[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("- **タグ**:") || trimmedLine.hasPrefix("- **タグ**：") {
                let parts = trimmedLine.components(separatedBy: ":")
                if parts.count > 1 {
                    let tagString = parts[1].trimmingCharacters(in: .whitespaces)
                    tags = tagString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            } else if trimmedLine == "---" {
                // セクション区切り
                continue
            } else if trimmedLine.hasPrefix("- **") {
                // 他のメタデータ行はスキップ
                continue
            } else if inContent || (!trimmedLine.isEmpty && !trimmedLine.hasPrefix("###")) {
                // 本文として追加
                if !trimmedLine.isEmpty {
                    contentLines.append(line)
                }
            }
        }

        let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // 内容がない場合はスキップ
        guard !content.isEmpty else { return nil }

        return QuickMemo(
            title: title,
            content: content,
            primaryCategory: category,
            tags: tags
        )
    }

    /// テキストファイルをインポートし、AIでタグを抽出するオプション付き
    func importTextFileWithMetadata(from url: URL, defaultCategory: String = "その他") throws -> [QuickMemo] {
        let data = try Data(contentsOf: url)
        let text = try decodeTextData(data)

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.noData
        }

        // ファイル名からタイトルを取得
        let fileName = url.deletingPathExtension().lastPathComponent

        let memo = QuickMemo(
            title: fileName,
            content: text.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryCategory: defaultCategory,
            tags: []
        )
        return [memo]
    }

    private func importJSONData(_ data: Data) throws -> [QuickMemo] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData = try decoder.decode(ExportData.self, from: data)

        return exportData.memos.map { exportMemo in
            QuickMemo(
                id: UUID(uuidString: exportMemo.id) ?? UUID(),
                title: exportMemo.title,
                content: exportMemo.content,
                primaryCategory: exportMemo.category,
                tags: exportMemo.tags,
                createdAt: exportMemo.timestamp,
                updatedAt: exportMemo.lastModified ?? exportMemo.timestamp,
                calendarEventId: exportMemo.calendarEventId,
                durationMinutes: exportMemo.durationMinutes ?? 30
            )
        }
    }

    private func importCSVData(_ data: Data) throws -> [QuickMemo] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingError
        }

        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ExportError.noData
        }

        var memos: [QuickMemo] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty { continue }

            let fields = parseCSVLine(line)
            guard fields.count >= 9 else { continue }

            let id = UUID(uuidString: fields[0]) ?? UUID()
            let title = fields[1]
            let content = fields[2]
            let category = fields[3]
            let tags = fields[4].isEmpty ? [] : fields[4].components(separatedBy: ";")
            let timestamp = dateFormatter.date(from: fields[5]) ?? Date()
            let lastModified: Date? = fields[6].isEmpty ? nil : dateFormatter.date(from: fields[6])
            let calendarEventId: String? = fields[7].isEmpty ? nil : fields[7]
            let durationMinutes = Int(fields.count > 8 ? fields[8] : "30") ?? 30

            let memo = QuickMemo(
                id: id,
                title: title,
                content: content,
                primaryCategory: category,
                tags: tags,
                createdAt: timestamp,
                updatedAt: lastModified ?? timestamp,
                calendarEventId: calendarEventId,
                durationMinutes: durationMinutes  // 修正: 正しく値を使用
            )
            memos.append(memo)
        }

        return memos
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = 0
        let characters = Array(line)

        while i < characters.count {
            let char = characters[i]

            if char == "\"" {
                if insideQuotes && i + 1 < characters.count && characters[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 1
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }

            i += 1
        }

        fields.append(currentField)
        return fields
    }
}

struct ExportData: Codable {
    let exportDate: Date
    let version: String
    let memos: [ExportMemo]
}

struct ArchivedExportData: Codable {
    let exportDate: Date
    let version: String
    let archivedMemos: [ArchivedMemo]
}

struct AllDataExport: Codable {
    let exportDate: Date
    let version: String
    let currentMemos: [QuickMemo]
    let archivedMemos: [ArchivedMemo]
}

struct ExportMemo: Codable {
    let id: String
    let title: String
    let content: String
    let category: String
    let tags: [String]
    let timestamp: Date
    let lastModified: Date?
    let calendarEventId: String?
    let durationMinutes: Int?
}