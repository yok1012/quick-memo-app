import Foundation
import EventKit
#if canImport(UIKit)
import UIKit
#endif

class CalendarService: ObservableObject {
    static let shared = CalendarService()
    private var eventStore = EKEventStore()
    private var quickMemoCalendar: EKCalendar?
    private let logger = CalendarLogger.shared

    @Published var hasCalendarAccess = false
    @Published var isLoading = false
    @Published var lastError: String? = nil
    @Published var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus {
        case unknown
        case checking
        case connected
        case disconnected
        case error(String)
    }
    
    private init() {
        refreshEventStore()
        checkAuthorizationStatus()
    }

    private func refreshEventStore() {
        eventStore = EKEventStore()
        eventStore.reset()
        eventStore.refreshSourcesIfNecessary()
        logger.log("EventStore refreshed and reset", level: .info)
    }
    
    @MainActor
    func requestCalendarAccess() async -> Bool {
        logger.log("Starting calendar access request...", level: .info)
        isLoading = true
        
        let status: Bool
        
        do {
            if #available(iOS 17.0, *) {
                logger.log("iOS 17+ detected, requesting full access", level: .info)
                status = try await eventStore.requestFullAccessToEvents()
            } else {
                logger.log("iOS <17 detected, requesting standard access", level: .info)
                status = try await eventStore.requestAccess(to: .event)
            }
            logger.log("Calendar access granted: \(status)", level: status ? .success : .warning)
        } catch {
            logger.log("Calendar access error", level: .error, details: nil, error: error)
            isLoading = false
            return false
        }
        
        hasCalendarAccess = status
        isLoading = false
        
        if status {
            logger.log("Setting up Quick Memo calendar...", level: .info)
            await setupQuickMemoCalendar()
        }
        
        return status
    }
    
    private func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            hasCalendarAccess = status == .fullAccess
            logger.log("権限状態確認 (iOS 17+)", level: .info, details: "Status: \(status.rawValue), Has Access: \(hasCalendarAccess)")
        } else {
            hasCalendarAccess = status == .authorized
            logger.log("権限状態確認 (iOS <17)", level: .info, details: "Status: \(status.rawValue), Has Access: \(hasCalendarAccess)")
        }
        
        if hasCalendarAccess {
            Task {
                await setupQuickMemoCalendar()
            }
        }
    }
    
    @MainActor
    private func setupQuickMemoCalendar() async {
        await Task.detached {
            do {
                let calendar = try await self.getOrCreateQuickMemoCalendar()
                await MainActor.run {
                    self.quickMemoCalendar = calendar
                    self.logger.log("Quick Memoカレンダー設定成功", level: .success, details: "Calendar: \(calendar.title), ID: \(calendar.calendarIdentifier)")
                }
            } catch {
                self.logger.log("カレンダー設定エラー", level: .error, details: nil, error: error)
            }
        }.value
    }
    
    private func getOrCreateQuickMemoCalendar() async throws -> EKCalendar {
        // EventStoreのソースが利用可能か確認
        logger.log("利用可能なソース数: \(eventStore.sources.count)", level: .info)
        for source in eventStore.sources {
            logger.log("ソース: \(source.title) (\(source.sourceType.rawValue)), カレンダー数: \(source.calendars(for: .event).count)", level: .info)
        }

        let calendars = eventStore.calendars(for: .event)
        logger.log("利用可能なカレンダー数: \(calendars.count)", level: .info)

        // 既存のQuick Memoカレンダーを探す
        if let existingCalendar = calendars.first(where: { $0.title == "Quick Memo" }) {
            // カレンダーの有効性を確認
            if existingCalendar.allowsContentModifications {
                logger.log("既存のQuick Memoカレンダーを使用", level: .info, details: "ID: \(existingCalendar.calendarIdentifier), 編集可能: \(existingCalendar.allowsContentModifications)")
                return existingCalendar
            } else {
                logger.log("既存のQuick Memoカレンダーは読み取り専用です", level: .warning)
                // 読み取り専用の場合は削除を試みる（ローカルカレンダーの場合のみ）
                if existingCalendar.source.sourceType == .local {
                    do {
                        try eventStore.removeCalendar(existingCalendar, commit: true)
                        logger.log("読み取り専用ローカルカレンダーを削除しました", level: .info)
                    } catch {
                        logger.log("読み取り専用カレンダーの削除に失敗", level: .error, error: error)
                    }
                }
            }
        }

        // 既存の書き込み可能なカレンダーがある場合はそれを使用
        // デフォルトカレンダーがある場合は優先して使用
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
           defaultCalendar.allowsContentModifications {
            logger.log("デフォルトカレンダーを使用", level: .info, details: "Title: \(defaultCalendar.title), ID: \(defaultCalendar.calendarIdentifier)")
            return defaultCalendar
        }

        // その他の書き込み可能なカレンダーを探す
        if let writableCalendar = calendars.first(where: { $0.allowsContentModifications }) {
            logger.log("既存の書き込み可能なカレンダーを使用", level: .info, details: "Title: \(writableCalendar.title), ID: \(writableCalendar.calendarIdentifier)")
            return writableCalendar
        }

        logger.log("新規Quick Memoカレンダーを作成中...", level: .info)
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "Quick Memo"
        #if canImport(UIKit)
        newCalendar.cgColor = UIColor.systemBlue.cgColor
        #endif
        
        // カレンダーソースの選択（優先順位付き）
        var selectedSource: EKSource?

        // 各ソースタイプの存在を確認
        let hasLocalSource = eventStore.sources.contains { $0.sourceType == .local }
        let hasCalDAVSource = eventStore.sources.contains { $0.sourceType == .calDAV }
        let hasExchangeSource = eventStore.sources.contains { $0.sourceType == .exchange }

        logger.log("ソースタイプ: Local=\(hasLocalSource), CalDAV=\(hasCalDAVSource), Exchange=\(hasExchangeSource)", level: .info)

        // 1. ローカルソースを最優先（最も確実に新規カレンダーを作成できる）
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            selectedSource = localSource
            logger.log("ローカルソース使用", level: .info, details: "\(localSource.title)")
        }

        // 2. iCloud/CalDAVソースを探す（iCloudは通常カレンダー作成可能）
        if selectedSource == nil {
            if let calDAVSource = eventStore.sources.first(where: { source in
                source.sourceType == .calDAV &&
                // iCloudソースを優先
                (source.title.lowercased().contains("icloud") || source.title.lowercased().contains("home"))
            }) {
                selectedSource = calDAVSource
                logger.log("iCloud/CalDAVソース使用", level: .info, details: "\(calDAVSource.title)")
            }
        }

        // 3. デフォルトカレンダーのソースを試す（ただしExchange/Googleなど制限のあるアカウントは避ける）
        if selectedSource == nil {
            if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
               defaultCalendar.allowsContentModifications,
               defaultCalendar.source.sourceType != .exchange &&
               !defaultCalendar.source.title.lowercased().contains("google") &&
               !defaultCalendar.source.title.lowercased().contains("gmail") {
                selectedSource = defaultCalendar.source
                logger.log("デフォルトソース使用", level: .info, details: "\(defaultCalendar.source.title) (\(defaultCalendar.source.sourceType.rawValue))")
            }
        }

        // 4. その他のCalDAVソース
        if selectedSource == nil {
            if let calDAVSource = eventStore.sources.first(where: { source in
                source.sourceType == .calDAV &&
                !source.title.lowercased().contains("google") &&
                !source.title.lowercased().contains("gmail")
            }) {
                selectedSource = calDAVSource
                logger.log("CalDAVソース使用", level: .info, details: "\(calDAVSource.title)")
            }
        }

        // 5. 最後の手段：ローカルソースを作成することはできないので、既存のカレンダーを使用する必要がある
        if selectedSource == nil {
            logger.log("新規カレンダー作成可能なソースが見つかりません", level: .warning, details: "既存のカレンダーを使用します")
            // 既存のカレンダーを使用することを返す
            if let existingCalendar = eventStore.defaultCalendarForNewEvents {
                logger.log("デフォルトカレンダーを返します", level: .info, details: "Title: \(existingCalendar.title)")
                return existingCalendar
            }
            if let anyCalendar = eventStore.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
                logger.log("既存の書き込み可能カレンダーを返します", level: .info, details: "Title: \(anyCalendar.title)")
                return anyCalendar
            }
        }

        guard let source = selectedSource else {
            let availableSources = eventStore.sources.map { "\($0.title) (\($0.sourceType.rawValue))" }.joined(separator: ", ")
            logger.log("利用可能なカレンダーソースが見つかりません", level: .error, details: "利用可能なソース: \(availableSources)")
            throw NSError(domain: "CalendarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "カレンダーソースが見つかりません"])
        }
        
        newCalendar.source = source
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            logger.log("Quick Memoカレンダー作成成功", level: .success, details: "ID: \(newCalendar.calendarIdentifier)")
            return newCalendar
        } catch {
            logger.log("カレンダー保存エラー", level: .error, details: nil, error: error)
            throw error
        }
    }
    
    func createCalendarEvent(for memo: QuickMemo) async -> String? {
        logger.log("Creating calendar event for memo", level: .info, details: "Memo ID: \(memo.id)")
        
        // 権限の再確認
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard authStatus == .fullAccess else {
                logger.log("カレンダーフルアクセス権限がありません", level: .error, details: "Status: \(authStatus.rawValue)")
                lastError = "カレンダーアクセス権限がありません"
                return nil
            }
        } else {
            guard authStatus == .authorized else {
                logger.log("カレンダーアクセス権限がありません", level: .error, details: "Status: \(authStatus.rawValue)")
                lastError = "カレンダーアクセス権限がありません"
                return nil
            }
        }

        // EventStoreをリフレッシュ
        refreshEventStore()

        // カレンダーが設定されていない場合は再取得を試みる
        if quickMemoCalendar == nil {
            logger.log("カレンダーが設定されていません。再取得を試みます...", level: .warning)
            await setupQuickMemoCalendar()
        }

        // 再度カレンダーを検証
        guard let calendar = quickMemoCalendar else {
            logger.log("Quick Memoカレンダーが取得できません", level: .error)
            lastError = "Quick Memoカレンダーが取得できません"
            return nil
        }
        
        // カレンダーが有効か確認
        if !eventStore.calendars(for: .event).contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            logger.log("カレンダーが無効です。再作成を試みます...", level: .warning)
            quickMemoCalendar = nil
            await setupQuickMemoCalendar()
            guard let newCalendar = quickMemoCalendar else {
                logger.log("カレンダー再作成に失敗しました", level: .error)
                lastError = "カレンダーの再作成に失敗しました"
                return nil
            }
            return await createCalendarEvent(for: memo)
        }

        let event = EKEvent(eventStore: eventStore)
        // タイトルがある場合はそれを使用、ない場合はコンテンツの先頭を使用
        if !memo.title.isEmpty {
            event.title = "[\(memo.primaryCategory)] \(memo.title)"
        } else {
            event.title = "[\(memo.primaryCategory)] \(String(memo.content.prefix(20)))"
        }
        event.notes = """
        メモ内容: \(memo.content)
        カテゴリ: \(memo.primaryCategory)
        タグ: \(memo.tags.joined(separator: ", "))
        作成日時: \(DateFormatter.localizedString(from: memo.createdAt, dateStyle: .medium, timeStyle: .short))
        """

        event.startDate = memo.createdAt
        event.endDate = event.startDate.addingTimeInterval(TimeInterval(memo.durationMinutes * 60))
        event.calendar = calendar
        event.isAllDay = false
        
        // アラームを無効化（実機での問題対策）
        event.alarms = nil
        
        logger.log("イベント作成準備完了", level: .info, details: "Title: \(event.title ?? ""), Calendar: \(calendar.title), Start: \(event.startDate), End: \(event.endDate)")

        // イベントの保存を試みる（リトライ機能付き）
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                // 新しいEventStoreインスタンスでリトライ
                if retryCount > 0 {
                    logger.log("リトライ \(retryCount)/\(maxRetries)", level: .warning)
                    refreshEventStore()
                    event.calendar = quickMemoCalendar
                }
                
                try eventStore.save(event, span: .thisEvent, commit: true)
                
                // 保存後の検証
                if let savedEvent = eventStore.event(withIdentifier: event.eventIdentifier) {
                    logger.log("イベント保存検証成功", level: .success, details: "Event ID: \(event.eventIdentifier ?? "unknown")")
                    logger.log("カレンダーイベント作成成功", level: .success, details: "Event ID: \(event.eventIdentifier ?? "unknown"), Title: \(event.title ?? ""), Calendar: \(calendar.title)")
                    lastError = nil
                    return event.eventIdentifier
                } else {
                    logger.log("イベント保存検証失敗", level: .warning, details: "Event not found after save")
                    retryCount += 1
                    if retryCount < maxRetries {
                        do {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                        } catch {
                            logger.log("スリープ中にエラー発生", level: .error, error: error)
                        }
                    }
                }
            } catch {
                let nsError = error as NSError
                logger.log("保存エラー (リトライ \(retryCount)/\(maxRetries))", level: .error, details: "Code: \(nsError.code), Domain: \(nsError.domain)", error: error)
                
                // エラーコードに基づいた処理
                if nsError.domain == "EKErrorDomain" {
                    switch nsError.code {
                    case 1: // No calendar selected
                        quickMemoCalendar = nil
                        await setupQuickMemoCalendar()
                    case 17: // Calendar is read-only
                        logger.log("カレンダーが読み取り専用です", level: .error)
                        lastError = "選択されたカレンダーは読み取り専用です"
                        return nil
                    default:
                        break
                    }
                }
                
                retryCount += 1
                if retryCount < maxRetries {
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                    } catch {
                        logger.log("スリープ中にエラー発生", level: .error, error: error)
                        lastError = "処理中にエラーが発生しました"
                        return nil
                    }
                } else {
                    lastError = "カレンダーイベント作成エラー: \(error.localizedDescription)"
                    return nil
                }
            }
        }
        
        logger.log("リトライ上限に達しました", level: .error)
        lastError = "カレンダーイベントの作成に失敗しました（リトライ上限）"
        return nil
    }
    
    func updateCalendarEvent(eventId: String, for memo: QuickMemo) async -> Bool {
        logger.log("Updating calendar event", level: .info, details: "Event ID: \(eventId)")
        
        guard hasCalendarAccess, let event = eventStore.event(withIdentifier: eventId) else {
            logger.log("Cannot update event - no access or event not found", level: .error, details: "Event ID: \(eventId)")
            return false
        }
        
        event.title = "[\(memo.primaryCategory)] \(String(memo.content.prefix(20)))"
        event.notes = """
        メモ内容: \(memo.content)
        カテゴリ: \(memo.primaryCategory)
        タグ: \(memo.tags.joined(separator: ", "))
        更新日時: \(DateFormatter.localizedString(from: memo.updatedAt, dateStyle: .medium, timeStyle: .short))
        """
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            logger.log("カレンダーイベント更新成功", level: .success, details: "Event ID: \(eventId)")
            lastError = nil
            return true
        } catch {
            logger.log("カレンダーイベント更新エラー", level: .error, details: "Event ID: \(eventId)", error: error)
            lastError = "カレンダーイベント更新エラー: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteCalendarEvent(eventId: String) async -> Bool {
        logger.log("Deleting calendar event", level: .info, details: "Event ID: \(eventId)")
        
        guard hasCalendarAccess, let event = eventStore.event(withIdentifier: eventId) else {
            logger.log("Cannot delete event - no access or event not found", level: .error, details: "Event ID: \(eventId)")
            return false
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
            logger.log("カレンダーイベント削除成功", level: .success, details: "Event ID: \(eventId)")
            lastError = nil
            return true
        } catch {
            logger.log("カレンダーイベント削除エラー", level: .error, details: "Event ID: \(eventId)", error: error)
            lastError = "カレンダーイベント削除エラー: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Connection Testing

    @MainActor
    func testCalendarConnection() async -> Bool {
        connectionStatus = .checking
        logger.log("カレンダー接続テスト開始...", level: .info)

        // 1. 権限確認
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard status == .fullAccess else {
                let error = "カレンダーへのフルアクセス権限がありません (Status: \(status.rawValue))"
                logger.log(error, level: .error)
                connectionStatus = .error(error)
                return false
            }
        } else {
            guard status == .authorized else {
                let error = "カレンダーへのアクセス権限がありません (Status: \(status.rawValue))"
                logger.log(error, level: .error)
                connectionStatus = .error(error)
                return false
            }
        }

        // 2. EventStoreリフレッシュ
        refreshEventStore()

        // 3. カレンダー取得テスト
        do {
            let calendar = try await getOrCreateQuickMemoCalendar()
            quickMemoCalendar = calendar

            // 4. テストイベント作成・削除
            let testEvent = EKEvent(eventStore: eventStore)
            testEvent.title = "[接続テスト] Quick Memo"
            testEvent.startDate = Date()
            testEvent.endDate = Date().addingTimeInterval(60)
            testEvent.calendar = calendar
            testEvent.alarms = nil

            try eventStore.save(testEvent, span: .thisEvent, commit: true)
            logger.log("テストイベント作成成功", level: .success, details: "Event ID: \(testEvent.eventIdentifier ?? "unknown")")
            
            // 保存確認
            if let _ = eventStore.event(withIdentifier: testEvent.eventIdentifier) {
                logger.log("テストイベント確認成功", level: .success)
                try eventStore.remove(testEvent, span: .thisEvent, commit: true)
                logger.log("テストイベント削除成功", level: .success)
            } else {
                logger.log("テストイベントが見つかりません", level: .warning)
            }

            connectionStatus = .connected
            logger.log("カレンダー接続テスト成功", level: .success)
            return true
        } catch {
            let errorMessage = "接続テスト失敗"
            logger.log(errorMessage, level: .error, details: nil, error: error)
            connectionStatus = .error("\(errorMessage): \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func reconnectCalendar() async -> Bool {
        logger.log("カレンダー再接続開始...", level: .info)
        isLoading = true

        // EventStoreをリフレッシュ
        refreshEventStore()

        // 権限を再確認
        let hasAccess = await requestCalendarAccess()

        if hasAccess {
            // 接続テストを実行
            let testResult = await testCalendarConnection()
            isLoading = false
            return testResult
        }

        isLoading = false
        return false
    }
}

// MARK: - Device-specific Sync
extension CalendarService {
    /// 実機での同期問題を解決するための強制リフレッシュメソッド
    @MainActor
    func forceCalendarSync() async -> Bool {
        logger.log("強制カレンダー同期開始", level: .info)
        
        // 1. EventStoreをリセット
        eventStore.reset()
        eventStore = EKEventStore()
        
        // 2. 少し待機して同期を待つ
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 3. ソースをリフレッシュ
        eventStore.refreshSourcesIfNecessary()
        
        // 4. 権限の再確認と再設定
        let hasAccess = await requestCalendarAccess()
        
        if hasAccess {
            logger.log("強制同期完了", level: .success)
            return true
        } else {
            logger.log("強制同期失敗", level: .error)
            return false
        }
    }
    
    /// カレンダーキャッシュをクリア
    func clearCalendarCache() {
        quickMemoCalendar = nil
        eventStore.reset()
        logger.log("カレンダーキャッシュをクリアしました", level: .info)
    }
}

extension QuickMemo {
    mutating func createCalendarEvent() {
        let memo = self
        Task {
            // 実機での同期問題対策: より長い遅延
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            let eventId = await CalendarService.shared.createCalendarEvent(for: memo)
            if let eventId = eventId {
                await MainActor.run {
                    var updatedMemo = memo
                    updatedMemo.calendarEventId = eventId
                    DataManager.shared.updateMemo(updatedMemo)
                }
            }
        }
    }
    
    mutating func updateCalendarEvent() {
        let memo = self
        let existingEventId = calendarEventId
        Task {
            if let eventId = existingEventId {
                await CalendarService.shared.updateCalendarEvent(eventId: eventId, for: memo)
            } else {
                let eventId = await CalendarService.shared.createCalendarEvent(for: memo)
                if let eventId = eventId {
                    await MainActor.run {
                        var updatedMemo = memo
                        updatedMemo.calendarEventId = eventId
                        DataManager.shared.updateMemo(updatedMemo)
                    }
                }
            }
        }
    }
    
    mutating func deleteCalendarEvent() {
        let memo = self
        let existingEventId = calendarEventId
        Task {
            if let eventId = existingEventId {
                let success = await CalendarService.shared.deleteCalendarEvent(eventId: eventId)
                if success {
                    await MainActor.run {
                        var updatedMemo = memo
                        updatedMemo.calendarEventId = nil
                        DataManager.shared.updateMemo(updatedMemo)
                    }
                }
            }
        }
    }
}