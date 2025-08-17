import Foundation
import EventKit
#if canImport(UIKit)
import UIKit
#endif

class CalendarService: ObservableObject {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()
    private var quickMemoCalendar: EKCalendar?
    
    @Published var hasCalendarAccess = false
    @Published var isLoading = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    @MainActor
    func requestCalendarAccess() async -> Bool {
        print("Starting calendar access request...")
        isLoading = true
        
        let status: Bool
        
        do {
            if #available(iOS 17.0, *) {
                print("iOS 17+ detected, requesting full access")
                status = try await eventStore.requestFullAccessToEvents()
            } else {
                print("iOS <17 detected, requesting standard access")
                status = try await eventStore.requestAccess(to: .event)
            }
            print("Calendar access granted: \(status)")
        } catch {
            print("Calendar access error: \(error.localizedDescription)")
            isLoading = false
            return false
        }
        
        hasCalendarAccess = status
        isLoading = false
        
        if status {
            print("Setting up Quick Memo calendar...")
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
                print("カレンダー設定エラー: \(error)")
            }
        }.value
    }
    
    private func getOrCreateQuickMemoCalendar() async throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        
        if let existingCalendar = calendars.first(where: { $0.title == "Quick Memo" }) {
            return existingCalendar
        }
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "Quick Memo"
        #if canImport(UIKit)
        newCalendar.cgColor = UIColor.systemBlue.cgColor
        #endif
        
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = source
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
    
    func createCalendarEvent(for memo: QuickMemo) async -> String? {
        guard hasCalendarAccess, let calendar = quickMemoCalendar else {
            return nil
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "[\(memo.primaryCategory)] \(String(memo.content.prefix(20)))"
        event.notes = """
        メモ内容: \(memo.content)
        カテゴリ: \(memo.primaryCategory)
        タグ: \(memo.tags.joined(separator: ", "))
        作成日時: \(DateFormatter.localizedString(from: memo.createdAt, dateStyle: .medium, timeStyle: .short))
        """
        
        event.startDate = memo.createdAt
        event.endDate = event.startDate.addingTimeInterval(3600)
        event.calendar = calendar
        event.isAllDay = false
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("カレンダーイベント作成エラー: \(error)")
            return nil
        }
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
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("カレンダーイベント更新エラー: \(error)")
            return false
        }
    }
    
    func deleteCalendarEvent(eventId: String) async -> Bool {
        guard hasCalendarAccess, let event = eventStore.event(withIdentifier: eventId) else {
            return false
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            return true
        } catch {
            print("カレンダーイベント削除エラー: \(error)")
            return false
        }
    }
}

extension QuickMemo {
    mutating func createCalendarEvent() {
        let memo = self
        Task {
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