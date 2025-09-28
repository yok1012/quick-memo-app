import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    // 初期化フラグを追加
    private static var isInitialized = false
    
    @Published var isNotificationEnabled = false
    @Published var notificationInterval = 30 // 分単位
    @Published var isQuietModeEnabled = false
    @Published var quietModeStartTime = Date()
    @Published var quietModeEndTime = Date()
    
    private let notificationIdentifierPrefix = "quickMemo.reminder"
    private let maxNotifications = 64 // iOS limit
    private var isInitializing = true
    private var purchaseStatusObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        loadSettings()
        isInitializing = false
        
        // 通知の登録を遅延実行（より長い遅延）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupPurchaseStatusObserver()
        }
    }
    
    deinit {
        if let observer = purchaseStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupPurchaseStatusObserver() {
        // 購入状態の変更を監視（今後の拡張用）
        purchaseStatusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PurchaseStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // 必要に応じて処理を追加
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isNotificationEnabled = defaults.bool(forKey: "NotificationEnabled")
        notificationInterval = defaults.integer(forKey: "NotificationInterval")
        if notificationInterval == 0 {
            notificationInterval = 30
        }
        isQuietModeEnabled = defaults.bool(forKey: "QuietModeEnabled")
        
        if let startData = defaults.data(forKey: "QuietModeStartTime"),
           let start = try? JSONDecoder().decode(Date.self, from: startData) {
            quietModeStartTime = start
        } else {
            // デフォルト: 22:00
            var components = Calendar.current.dateComponents([.hour, .minute], from: Date())
            components.hour = 22
            components.minute = 0
            quietModeStartTime = Calendar.current.date(from: components) ?? Date()
        }
        
        if let endData = defaults.data(forKey: "QuietModeEndTime"),
           let end = try? JSONDecoder().decode(Date.self, from: endData) {
            quietModeEndTime = end
        } else {
            // デフォルト: 7:00
            var components = Calendar.current.dateComponents([.hour, .minute], from: Date())
            components.hour = 7
            components.minute = 0
            quietModeEndTime = Calendar.current.date(from: components) ?? Date()
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isNotificationEnabled, forKey: "NotificationEnabled")
        defaults.set(notificationInterval, forKey: "NotificationInterval")
        defaults.set(isQuietModeEnabled, forKey: "QuietModeEnabled")
        
        if let startData = try? JSONEncoder().encode(quietModeStartTime) {
            defaults.set(startData, forKey: "QuietModeStartTime")
        }
        if let endData = try? JSONEncoder().encode(quietModeEndTime) {
            defaults.set(endData, forKey: "QuietModeEndTime")
        }
        
        // 初期化中はスケジュールしない
        guard !isInitializing else { return }
        
        // 設定が変更されたら通知を再スケジュール（遅延実行）
        if isNotificationEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.scheduleNotifications()
            }
        } else {
            cancelAllNotifications()
        }
    }
    
    // MARK: - Permission Management
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationEnabled = granted
                self.saveSettings()
                completion(granted)
                
                if granted {
                    self.scheduleNotifications()
                }
            }
        }
    }
    
    func checkPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized
                completion(granted)
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotifications() {

        Task { @MainActor in
            let isEnabled = self.isNotificationEnabled
            let interval = self.notificationInterval
            let quietModeEnabled = self.isQuietModeEnabled
            let quietStart = self.quietModeStartTime
            let quietEnd = self.quietModeEndTime

            guard isEnabled else {
                return
            }
            
            // バックグラウンドスレッドで実行
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.cancelAllNotifications()
                
                self.scheduleNotificationsInBackground(
                    interval: interval,
                    quietModeEnabled: quietModeEnabled,
                    quietStart: quietStart,
                    quietEnd: quietEnd
                )
            }
        }
    }
    
    private func scheduleNotificationsInBackground(
        interval: Int,
        quietModeEnabled: Bool,
        quietStart: Date,
        quietEnd: Date
    ) {
        
        let content = UNMutableNotificationContent()
        content.title = "メモを記録しましょう"
        content.body = "今の気持ちや思いついたことを記録してみませんか？"
        content.sound = .default
        
        // 次の通知時刻を計算
        let now = Date()
        var nextNotificationDates: [Date] = []
        
        // 現在時刻から開始
        var currentTime = now
        var loopCount = 0
        let maxLoops = 1000 // 無限ループ防止
        
        // 最大で64個の通知をスケジュール（iOS制限）
        while nextNotificationDates.count < maxNotifications && loopCount < maxLoops {
            loopCount += 1
            
            // 次の通知時刻を計算
            if let nextTime = Calendar.current.date(byAdding: .minute, value: interval, to: currentTime) {
                currentTime = nextTime
                
                // おやすみモードのチェック
                if !isInQuietModeWithParams(
                    date: currentTime,
                    quietModeEnabled: quietModeEnabled,
                    quietStart: quietStart,
                    quietEnd: quietEnd
                ) {
                    nextNotificationDates.append(currentTime)
                }
                
                // 7日以上先の場合は終了
                if currentTime.timeIntervalSince(now) > 7 * 24 * 60 * 60 {
                    break
                }
            } else {
                // 日付計算に失敗した場合は終了
                break
            }
        }
            
        if loopCount >= maxLoops {
            return
        }
        
        
        // 通知をスケジュール（メインキューで実行しない）
        let totalCount = nextNotificationDates.count
        
        // 通知がない場合は早期リターン
        guard totalCount > 0 else {
            return
        }
        
        // スレッドセーフなカウンター
        let queue = DispatchQueue(label: "notification.counter.queue", attributes: .concurrent)
        var pendingRequests = totalCount
        var successCount = 0
        
        for (index, date) in nextNotificationDates.enumerated() {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "\(notificationIdentifierPrefix).\(index)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                queue.async(flags: .barrier) {
                    if let error = error {
                    } else {
                        successCount += 1
                    }
                    
                    pendingRequests -= 1
                    if pendingRequests == 0 {
                    }
                }
            }
        }
    }
    
    private func isInQuietMode(date: Date) -> Bool {
        guard isQuietModeEnabled else { return false }
        
        return isInQuietModeWithParams(
            date: date,
            quietModeEnabled: isQuietModeEnabled,
            quietStart: quietModeStartTime,
            quietEnd: quietModeEndTime
        )
    }
    
    private func isInQuietModeWithParams(
        date: Date,
        quietModeEnabled: Bool,
        quietStart: Date,
        quietEnd: Date
    ) -> Bool {
        guard quietModeEnabled else { return false }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietEnd)
        
        guard let hour = components.hour, let minute = components.minute,
              let startHour = startComponents.hour, let startMinute = startComponents.minute,
              let endHour = endComponents.hour, let endMinute = endComponents.minute else {
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        // 日をまたぐ場合
        if startMinutes > endMinutes {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "テスト通知"
        content.body = "通知が正常に動作しています"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
            }
        }
    }
}