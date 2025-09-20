import Foundation

class CalendarLogger: ObservableObject {
    static let shared = CalendarLogger()
    
    @Published private(set) var logs: [LogEntry] = []
    private let maxLogs = 100
    private let userDefaults = UserDefaults.standard
    private let logsKey = "calendarLogs"
    
    struct LogEntry: Codable, Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let details: String?
        let error: String?
        
        enum LogLevel: String, Codable {
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
            case success = "SUCCESS"
            
            var color: String {
                switch self {
                case .info: return "#007AFF"
                case .warning: return "#FF9500"
                case .error: return "#FF3B30"
                case .success: return "#34C759"
                }
            }
        }
    }
    
    private init() {
        loadLogs()
    }
    
    func log(_ message: String, level: LogEntry.LogLevel = .info, details: String? = nil, error: Error? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            details: details,
            error: error?.localizedDescription
        )
        
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0)
            if self.logs.count > self.maxLogs {
                self.logs = Array(self.logs.prefix(self.maxLogs))
            }
            self.saveLogs()
        }
        
        // デバッグ用にコンソールにも出力
        print("[\(level.rawValue)] \(message)")
        if let details = details {
            print("Details: \(details)")
        }
        if let error = error {
            print("Error: \(error)")
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.saveLogs()
        }
    }
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            userDefaults.set(encoded, forKey: logsKey)
        }
    }
    
    private func loadLogs() {
        if let data = userDefaults.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            self.logs = decoded
        }
    }
    
    // 診断情報を生成
    func generateDiagnosticReport() -> String {
        var report = "Calendar Diagnostic Report\n"
        report += "Generated: \(Date())\n"
        report += "=========================\n\n"
        
        // 最近のエラーのサマリー
        let recentErrors = logs.filter { $0.level == .error }.prefix(10)
        report += "Recent Errors (\(recentErrors.count)):\n"
        for error in recentErrors {
            report += "- \(error.timestamp): \(error.message)\n"
            if let details = error.error {
                report += "  Error: \(details)\n"
            }
        }
        
        report += "\n"
        
        // 操作の統計
        let successCount = logs.filter { $0.level == .success }.count
        let errorCount = logs.filter { $0.level == .error }.count
        let totalOperations = logs.filter { $0.message.contains("Creating event") || $0.message.contains("Updating event") }.count
        
        report += "Statistics:\n"
        report += "- Total operations: \(totalOperations)\n"
        report += "- Successful: \(successCount)\n"
        report += "- Failed: \(errorCount)\n"
        if totalOperations > 0 {
            let successRate = Double(successCount) / Double(totalOperations) * 100
            report += "- Success rate: \(String(format: "%.1f", successRate))%\n"
        }
        
        return report
    }
}