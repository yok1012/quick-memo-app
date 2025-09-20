import SwiftUI

struct CalendarDebugView: View {
    @StateObject private var logger = CalendarLogger.shared
    @StateObject private var calendarService = CalendarService.shared
    @State private var showingDiagnosticReport = false
    @State private var diagnosticReport = ""
    @State private var showingConnectionTest = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("カレンダー状態") {
                    HStack {
                        Text("アクセス権限")
                        Spacer()
                        Text(calendarService.hasCalendarAccess ? "許可済み" : "未許可")
                            .foregroundColor(calendarService.hasCalendarAccess ? .green : .red)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("接続状態")
                        Spacer()
                        connectionStatusView
                    }
                    
                    if let lastError = calendarService.lastError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最後のエラー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(lastError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section("アクション") {
                    Button(action: {
                        Task {
                            await testConnection()
                        }
                    }) {
                        HStack {
                            Label("接続テスト", systemImage: "network")
                            if showingConnectionTest {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(showingConnectionTest)
                    
                    Button(action: {
                        Task {
                            await calendarService.reconnectCalendar()
                        }
                    }) {
                        Label("カレンダー再接続", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        Task {
                            await calendarService.forceCalendarSync()
                        }
                    }) {
                        Label("強制同期", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .foregroundColor(.orange)
                    
                    Button(action: {
                        calendarService.clearCalendarCache()
                    }) {
                        Label("キャッシュクリア", systemImage: "clear")
                    }
                    
                    Button(action: generateDiagnosticReport) {
                        Label("診断レポート生成", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button(action: {
                        logger.clearLogs()
                    }) {
                        Label("ログをクリア", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                Section("最近のログ") {
                    if logger.logs.isEmpty {
                        Text("ログがありません")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(logger.logs.prefix(50)) { log in
                            LogRowView(log: log)
                        }
                    }
                }
            }
            .navigationTitle("カレンダーデバッグ")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await testConnection()
            }
            .sheet(isPresented: $showingDiagnosticReport) {
                DiagnosticReportView(report: diagnosticReport)
            }
        }
    }
    
    @ViewBuilder
    private var connectionStatusView: some View {
        switch calendarService.connectionStatus {
        case .unknown:
            Text("不明")
                .foregroundColor(.secondary)
        case .checking:
            HStack {
                Text("確認中...")
                ProgressView()
                    .scaleEffect(0.7)
            }
        case .connected:
            Text("接続済み")
                .foregroundColor(.green)
                .fontWeight(.medium)
        case .disconnected:
            Text("切断")
                .foregroundColor(.orange)
                .fontWeight(.medium)
        case .error(let message):
            Text(message)
                .foregroundColor(.red)
                .font(.caption)
        }
    }
    
    private func testConnection() async {
        showingConnectionTest = true
        _ = await calendarService.testCalendarConnection()
        showingConnectionTest = false
    }
    
    private func generateDiagnosticReport() {
        diagnosticReport = logger.generateDiagnosticReport()
        showingDiagnosticReport = true
    }
}

struct LogRowView: View {
    let log: CalendarLogger.LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color(hex: log.level.color))
                    .frame(width: 8, height: 8)
                
                Text(log.level.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: log.level.color))
                
                Text(formatDate(log.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if log.details != nil || log.error != nil {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(log.message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            
            if isExpanded {
                if let details = log.details {
                    Text("詳細: \(details)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
                
                if let error = log.error {
                    Text("エラー: \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if log.details != nil || log.error != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct DiagnosticReportView: View {
    let report: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(report)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("診断レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(item: report) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}