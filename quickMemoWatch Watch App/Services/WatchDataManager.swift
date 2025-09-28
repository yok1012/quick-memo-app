import Foundation
import SwiftUI
import Combine

class WatchDataManager: ObservableObject {
    static let shared = WatchDataManager()

    @Published var memos: [WatchMemo] = []
    @Published var categories: [WatchCategory] = []

    private let userDefaults = UserDefaults.standard
    private let memosKey = "watchMemos"
    private let categoriesKey = "watchCategories"

    private init() {
        loadData()
        setupDefaultCategoriesIfNeeded()
    }

    private func setupDefaultCategoriesIfNeeded() {
        if categories.isEmpty {
            categories = WatchDefaultData.defaultCategories()
            saveCategories()
        }
    }

    func addMemo(_ memo: WatchMemo) {
        memos.insert(memo, at: 0)
        saveMemos()
    }

    func deleteMemo(_ memo: WatchMemo) {
        memos.removeAll { $0.id == memo.id }
        saveMemos()
    }

    func updateFromPhone(memos: [WatchMemo], categories: [WatchCategory]) {
        self.memos = memos
        self.categories = categories
        saveMemos()
        saveCategories()
    }

    private func loadData() {
        loadMemos()
        loadCategories()
    }

    private func loadMemos() {
        if let data = userDefaults.data(forKey: memosKey),
           let decoded = try? JSONDecoder().decode([WatchMemo].self, from: data) {
            memos = decoded
        }
    }

    private func loadCategories() {
        if let data = userDefaults.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([WatchCategory].self, from: data) {
            categories = decoded
        }
    }

    private func saveMemos() {
        if let encoded = try? JSONEncoder().encode(memos) {
            userDefaults.set(encoded, forKey: memosKey)
        }
    }

    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            userDefaults.set(encoded, forKey: categoriesKey)
        }
    }
}

enum WatchDefaultData {
    static func defaultCategories() -> [WatchCategory] {
        let L = WatchLocalization.shared.string
        return [
            WatchCategory(
                name: L("watch_category_work"),
                icon: "briefcase",
                color: "007AFF",
                defaultTags: workTags(),
                baseKey: "work"
            ),
            WatchCategory(
                name: L("watch_category_personal"),
                icon: "house",
                color: "34C759",
                defaultTags: personalTags(),
                baseKey: "personal"
            ),
            WatchCategory(
                name: L("watch_category_idea"),
                icon: "lightbulb",
                color: "FF9500",
                defaultTags: ideaTags(),
                baseKey: "idea"
            ),
            WatchCategory(
                name: L("watch_category_people"),
                icon: "person",
                color: "AF52DE",
                defaultTags: peopleTags(),
                baseKey: "people"
            ),
            WatchCategory(
                name: L("watch_category_other"),
                icon: "folder",
                color: "8E8E93",
                defaultTags: otherTags(),
                baseKey: "other"
            )
        ]
    }

    private static func workTags() -> [String] {
        let L = WatchLocalization.shared.string
        return [
            L("watch_tag_meeting"),
            L("watch_tag_task"),
            L("watch_tag_deadline"),
            L("watch_tag_idea")
        ]
    }

    private static func personalTags() -> [String] {
        let L = WatchLocalization.shared.string
        return [
            L("watch_tag_schedule"),
            L("watch_tag_memory"),
            L("watch_tag_health")
        ]
    }

    private static func ideaTags() -> [String] {
        let L = WatchLocalization.shared.string
        return [
            L("watch_tag_business"),
            L("watch_tag_creation"),
            L("watch_tag_improvement"),
            L("watch_tag_memo")
        ]
    }

    private static func peopleTags() -> [String] {
        let L = WatchLocalization.shared.string
        return [
            L("watch_tag_contacts"),
            L("watch_tag_conversation"),
            L("watch_tag_appointment"),
            L("watch_tag_relationship")
        ]
    }

    private static func otherTags() -> [String] {
        let L = WatchLocalization.shared.string
        return [
            L("watch_tag_misc"),
            L("watch_tag_temp"),
            L("watch_tag_pending"),
            L("watch_tag_hold")
        ]
    }
}

struct WatchLocalization {
    static let shared = WatchLocalization()

    private let translations: [String: [String: String]] = [
        "ja": [
            "watch_nav_title": "クイックメモ",
            "watch_category_section": "カテゴリー",
            "watch_title_label": "タイトル",
            "watch_title_placeholder": "タイトルを入力",
            "watch_title_scribble_title": "タイトルを入力",
            "watch_voice_input": "音声入力",
            "watch_recording": "録音中...",
            "watch_handwriting": "手書き入力",
            "watch_content_scribble_title": "メモ内容を入力",
            "watch_content_placeholder": "ここにメモを書く",
            "watch_tags_label": "タグ",
            "watch_tags_count": "%d / %d",
            "watch_tags_empty": "利用できるタグがありません",
            "watch_add_tag": "タグを追加",
            "watch_tag_scribble_title": "新しいタグ",
            "watch_tag_placeholder": "タグ名",
            "watch_tag_limit": "タグは最大 %d 件まで選択できます",
            "watch_preview": "プレビュー",
            "watch_save": "保存",
            "watch_cancel": "キャンセル",
            "watch_done": "完了",
            "watch_voice_sample": "音声入力メモ",
            "watch_category_work": "仕事",
            "watch_category_personal": "プライベート",
            "watch_category_idea": "アイデア",
            "watch_category_people": "人物",
            "watch_category_other": "その他",
            "watch_tag_meeting": "会議",
            "watch_tag_task": "タスク",
            "watch_tag_deadline": "締切",
            "watch_tag_idea": "アイデア",
            "watch_tag_schedule": "予定",
            "watch_tag_memory": "思い出",
            "watch_tag_health": "健康",
            "watch_tag_business": "ビジネス",
            "watch_tag_creation": "創作",
            "watch_tag_improvement": "改善",
            "watch_tag_memo": "メモ",
            "watch_tag_contacts": "連絡先",
            "watch_tag_conversation": "会話",
            "watch_tag_appointment": "約束",
            "watch_tag_relationship": "関係",
            "watch_tag_misc": "雑記",
            "watch_tag_temp": "一時",
            "watch_tag_pending": "保留",
            "watch_tag_hold": "確認待ち"
        ],
        "en": [
            "watch_nav_title": "Quick Memo",
            "watch_category_section": "Category",
            "watch_title_label": "Title",
            "watch_title_placeholder": "Enter title",
            "watch_title_scribble_title": "Enter Title",
            "watch_voice_input": "Voice Input",
            "watch_recording": "Recording...",
            "watch_handwriting": "Scribble",
            "watch_content_scribble_title": "Enter Memo",
            "watch_content_placeholder": "Write your memo",
            "watch_tags_label": "Tags",
            "watch_tags_count": "%d / %d",
            "watch_tags_empty": "No tags available",
            "watch_add_tag": "Add Tag",
            "watch_tag_scribble_title": "New Tag",
            "watch_tag_placeholder": "Tag name",
            "watch_tag_limit": "You can select up to %d tags",
            "watch_preview": "Preview",
            "watch_save": "Save",
            "watch_cancel": "Cancel",
            "watch_done": "Done",
            "watch_voice_sample": "Voice memo",
            "watch_category_work": "Work",
            "watch_category_personal": "Personal",
            "watch_category_idea": "Ideas",
            "watch_category_people": "People",
            "watch_category_other": "Other",
            "watch_tag_meeting": "Meeting",
            "watch_tag_task": "Task",
            "watch_tag_deadline": "Deadline",
            "watch_tag_idea": "Idea",
            "watch_tag_schedule": "Schedule",
            "watch_tag_memory": "Memories",
            "watch_tag_health": "Health",
            "watch_tag_business": "Business",
            "watch_tag_creation": "Creation",
            "watch_tag_improvement": "Improvements",
            "watch_tag_memo": "Memo",
            "watch_tag_contacts": "Contacts",
            "watch_tag_conversation": "Conversation",
            "watch_tag_appointment": "Appointment",
            "watch_tag_relationship": "Relationship",
            "watch_tag_misc": "Misc",
            "watch_tag_temp": "Temporary",
            "watch_tag_pending": "Pending",
            "watch_tag_hold": "On Hold"
        ],
        "zh-Hans": [
            "watch_nav_title": "快速备忘",
            "watch_category_section": "分类",
            "watch_title_label": "标题",
            "watch_title_placeholder": "输入标题",
            "watch_title_scribble_title": "输入标题",
            "watch_voice_input": "语音输入",
            "watch_recording": "录音中...",
            "watch_handwriting": "手写输入",
            "watch_content_scribble_title": "输入备忘内容",
            "watch_content_placeholder": "在此输入备忘",
            "watch_tags_label": "标签",
            "watch_tags_count": "%d / %d",
            "watch_tags_empty": "暂无可用标签",
            "watch_add_tag": "添加标签",
            "watch_tag_scribble_title": "新标签",
            "watch_tag_placeholder": "标签名称",
            "watch_tag_limit": "最多可选择 %d 个标签",
            "watch_preview": "预览",
            "watch_save": "保存",
            "watch_cancel": "取消",
            "watch_done": "完成",
            "watch_voice_sample": "语音备忘",
            "watch_category_work": "工作",
            "watch_category_personal": "私人",
            "watch_category_idea": "想法",
            "watch_category_people": "人物",
            "watch_category_other": "其他",
            "watch_tag_meeting": "会议",
            "watch_tag_task": "任务",
            "watch_tag_deadline": "截止",
            "watch_tag_idea": "灵感",
            "watch_tag_schedule": "日程",
            "watch_tag_memory": "回忆",
            "watch_tag_health": "健康",
            "watch_tag_business": "商务",
            "watch_tag_creation": "创意",
            "watch_tag_improvement": "改进",
            "watch_tag_memo": "备忘",
            "watch_tag_contacts": "联系人",
            "watch_tag_conversation": "交流",
            "watch_tag_appointment": "约定",
            "watch_tag_relationship": "关系",
            "watch_tag_misc": "杂记",
            "watch_tag_temp": "临时",
            "watch_tag_pending": "待处理",
            "watch_tag_hold": "搁置"
        ]
    ]

    func string(for key: String) -> String {
        let languageIdentifier = Locale.preferredLanguages.first ?? "en"
        let language = normalizedLanguageCode(from: languageIdentifier)
        if let value = translations[language]?[key] {
            return value
        }
        if let value = translations["en"]?[key] {
            return value
        }
        return key
    }

    private func normalizedLanguageCode(from identifier: String) -> String {
        if identifier.hasPrefix("ja") {
            return "ja"
        }
        if identifier.lowercased().hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }
}
