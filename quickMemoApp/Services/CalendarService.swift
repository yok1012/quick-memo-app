import Foundation
import EventKit
#if canImport(UIKit)
import UIKit
#endif

class CalendarService: ObservableObject {
    static let shared = CalendarService()
    private var eventStore = EKEventStore()
    private var quickMemoCalendar: EKCalendar?

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
    }
    
    @MainActor
    func requestCalendarAccess() async -> Bool {
        isLoading = true
        
        let status: Bool
        
        do {
            if #available(iOS 17.0, *) {
                status = try await eventStore.requestFullAccessToEvents()
            } else {
                status = try await eventStore.requestAccess(to: .event)
            }
        } catch {
            isLoading = false
            return false
        }
        
        hasCalendarAccess = status
        isLoading = false
        
        if status {
            await setupQuickMemoCalendar()
        }
        
        return status
    }
    
    private func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            hasCalendarAccess = status == .fullAccess
        } else {
            hasCalendarAccess = status == .authorized
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
                }
            } catch {
            }
        }.value
    }
    
    private func getOrCreateQuickMemoCalendar() async throws -> EKCalendar {
        // EventStoreのソースが利用可能か確認
        for source in eventStore.sources {
        }

        let calendars = eventStore.calendars(for: .event)

        // 既存のQuick Memoカレンダーを探す
        if let existingCalendar = calendars.first(where: { $0.title == "Quick Memo" }) {
            // カレンダーの有効性を確認
            if existingCalendar.allowsContentModifications {
                return existingCalendar
            } else {
                // 読み取り専用の場合は削除を試みる（ローカルカレンダーの場合のみ）
                if existingCalendar.source.sourceType == .local {
                    do {
                        try eventStore.removeCalendar(existingCalendar, commit: true)
                    } catch {
                    }
                }
            }
        }

        // 既存の書き込み可能なカレンダーがある場合はそれを使用
        // デフォルトカレンダーがある場合は優先して使用
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
           defaultCalendar.allowsContentModifications {
            return defaultCalendar
        }

        // その他の書き込み可能なカレンダーを探す
        if let writableCalendar = calendars.first(where: { $0.allowsContentModifications }) {
            return writableCalendar
        }

        
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


        // 1. ローカルソースを最優先（最も確実に新規カレンダーを作成できる）
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            selectedSource = localSource
        }

        // 2. iCloud/CalDAVソースを探す（iCloudは通常カレンダー作成可能）
        if selectedSource == nil {
            if let calDAVSource = eventStore.sources.first(where: { source in
                source.sourceType == .calDAV &&
                // iCloudソースを優先
                (source.title.lowercased().contains("icloud") || source.title.lowercased().contains("home"))
            }) {
                selectedSource = calDAVSource
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
            }
        }

        // 5. 最後の手段：ローカルソースを作成することはできないので、既存のカレンダーを使用する必要がある
        if selectedSource == nil {
            // 既存のカレンダーを使用することを返す
            if let existingCalendar = eventStore.defaultCalendarForNewEvents {
                return existingCalendar
            }
            if let anyCalendar = eventStore.calendars(for: .event).first(where: { $0.allowsContentModifications }) {
                return anyCalendar
            }
        }

        guard let source = selectedSource else {
            let availableSources = eventStore.sources.map { "\($0.title) (\($0.sourceType.rawValue))" }.joined(separator: ", ")
            throw NSError(domain: "CalendarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "カレンダーソースが見つかりません"])
        }
        
        newCalendar.source = source
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            throw error
        }
    }
    
    func createCalendarEvent(for memo: QuickMemo) async -> String? {
        
        // 権限の再確認
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard authStatus == .fullAccess else {
                lastError = "カレンダーアクセス権限がありません"
                return nil
            }
        } else {
            guard authStatus == .authorized else {
                lastError = "カレンダーアクセス権限がありません"
                return nil
            }
        }

        // EventStoreをリフレッシュ
        refreshEventStore()

        // カレンダーが設定されていない場合は再取得を試みる
        if quickMemoCalendar == nil {
            await setupQuickMemoCalendar()
        }

        // 再度カレンダーを検証
        guard let calendar = quickMemoCalendar else {
            lastError = "Quick Memoカレンダーが取得できません"
            return nil
        }
        
        // カレンダーが有効か確認
        if !eventStore.calendars(for: .event).contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            quickMemoCalendar = nil
            await setupQuickMemoCalendar()
            guard let newCalendar = quickMemoCalendar else {
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
        

        // イベントの保存を試みる（リトライ機能付き）
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                // 新しいEventStoreインスタンスでリトライ
                if retryCount > 0 {
                    refreshEventStore()
                    event.calendar = quickMemoCalendar
                }
                
                try eventStore.save(event, span: .thisEvent, commit: true)
                
                // 保存後の検証
                if let savedEvent = eventStore.event(withIdentifier: event.eventIdentifier) {
                    lastError = nil
                    return event.eventIdentifier
                } else {
                    retryCount += 1
                    if retryCount < maxRetries {
                        do {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                        } catch {
                        }
                    }
                }
            } catch {
                let nsError = error as NSError
                
                // エラーコードに基づいた処理
                if nsError.domain == "EKErrorDomain" {
                    switch nsError.code {
                    case 1: // No calendar selected
                        quickMemoCalendar = nil
                        await setupQuickMemoCalendar()
                    case 17: // Calendar is read-only
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
                        lastError = "処理中にエラーが発生しました"
                        return nil
                    }
                } else {
                    lastError = "カレンダーイベント作成エラー: \(error.localizedDescription)"
                    return nil
                }
            }
        }
        
        lastError = "カレンダーイベントの作成に失敗しました（リトライ上限）"
        return nil
    }
    
    func updateCalendarEvent(eventId: String, for memo: QuickMemo) async -> Bool {
        
        guard hasCalendarAccess, let event = eventStore.event(withIdentifier: eventId) else {
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
            lastError = nil
            return true
        } catch {
            lastError = "カレンダーイベント更新エラー: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteCalendarEvent(eventId: String) async -> Bool {
        
        guard hasCalendarAccess, let event = eventStore.event(withIdentifier: eventId) else {
            return false
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
            lastError = nil
            return true
        } catch {
            lastError = "カレンダーイベント削除エラー: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Connection Testing

    @MainActor
    func testCalendarConnection() async -> Bool {
        connectionStatus = .checking

        // 1. 権限確認
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard status == .fullAccess else {
                let error = "カレンダーへのフルアクセス権限がありません (Status: \(status.rawValue))"
                connectionStatus = .error(error)
                return false
            }
        } else {
            guard status == .authorized else {
                let error = "カレンダーへのアクセス権限がありません (Status: \(status.rawValue))"
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
            
            // 保存確認
            if let _ = eventStore.event(withIdentifier: testEvent.eventIdentifier) {
                try eventStore.remove(testEvent, span: .thisEvent, commit: true)
            } else {
            }

            connectionStatus = .connected
            return true
        } catch {
            let errorMessage = "接続テスト失敗"
            connectionStatus = .error("\(errorMessage): \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func reconnectCalendar() async -> Bool {
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
            return true
        } else {
            return false
        }
    }
    
    /// カレンダーキャッシュをクリア
    func clearCalendarCache() {
        quickMemoCalendar = nil
        eventStore.reset()
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