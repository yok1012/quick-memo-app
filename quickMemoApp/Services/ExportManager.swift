import Foundation
import SwiftUI

class ExportManager {
    static let shared = ExportManager()

    private init() {}

    enum ExportFormat {
        case csv
        case json
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

        guard let data = csvString.data(using: .utf8) else {
            throw ExportError.encodingError
        }

        return data
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

    private func escapeCSVField(_ field: String) -> String {
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n")
        if needsQuotes {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
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
        default:
            throw ExportError.encodingError
        }
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
                durationMinutes: 30
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