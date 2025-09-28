import SwiftUI
import WatchKit

private let tagSelectionLimit = 5

struct WatchMemoInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @ObservedObject private var dataManager = WatchDataManager.shared

    @State private var selectedCategoryID: UUID?
    @State private var selectedCategoryName: String?
    @State private var titleText: String = ""
    @State private var memoText: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var customTags: [String] = []
    @State private var isRecording = false
    @State private var showingContentScribble = false
    @State private var showingTitleScribble = false
    @State private var showingTagScribble = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    categorySelector
                    titleSection
                    inputMethods
                    tagsSection
                    if hasPreviewContent {
                        memoPreview
                    }
                    saveButton
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 8)
            .navigationTitle(localized("watch_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { ensureSelectedCategory() }
        .onChange(of: dataManager.categories) { _ in ensureSelectedCategory() }
        .onChange(of: selectedCategoryID) { _ in constrainSelectedTags() }
    }

    private var categories: [WatchCategory] {
        let current = dataManager.categories
        return current.isEmpty ? WatchDefaultData.defaultCategories() : current
    }

    private var selectedCategory: WatchCategory? {
        if let id = selectedCategoryID, let match = categories.first(where: { $0.id == id }) {
            return match
        }
        if let name = selectedCategoryName, let match = categories.first(where: { $0.name == name }) {
            return match
        }
        return categories.first
    }

    private var availableTags: [String] {
        selectedCategory?.defaultTags ?? []
    }

    private var hasPreviewContent: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !selectedTags.isEmpty
    }

    private func ensureSelectedCategory() {
        let currentCategories = categories
        guard !currentCategories.isEmpty else { return }

        if let id = selectedCategoryID, currentCategories.contains(where: { $0.id == id }) {
            return
        }

        if let name = selectedCategoryName, let match = currentCategories.first(where: { $0.name == name }) {
            selectedCategoryID = match.id
        } else {
            selectedCategoryID = currentCategories.first?.id
            selectedCategoryName = currentCategories.first?.name
        }
        selectedTags.removeAll()
    }

    private func constrainSelectedTags() {
        let current = Set(availableTags)
        selectedTags = selectedTags.intersection(current.union(Set(customTags)))
        customTags = customTags.filter { selectedTags.contains($0) }
        if let selected = selectedCategory {
            selectedCategoryName = selected.name
        }
    }

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("watch_category_section"))
                .font(.caption2)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        let isSelected = category.id == selectedCategory?.id
                        Button {
                            selectedCategoryID = category.id
                            selectedCategoryName = category.name
                            WKInterfaceDevice.current().play(.click)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 12, weight: .medium))
                                Text(category.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("watch_title_label"))
                .font(.caption2)
                .foregroundColor(.secondary)

            Button {
                showingTitleScribble = true
            } label: {
                HStack {
                    Text(titleText.isEmpty ? localized("watch_title_placeholder") : titleText)
                        .font(.caption)
                        .foregroundColor(titleText.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingTitleScribble) {
            WatchScribbleInputView(
                initialText: titleText,
                titleKey: "watch_title_scribble_title",
                placeholderKey: "watch_title_placeholder"
            ) { text in
                titleText = text
            }
        }
    }

    private var inputMethods: some View {
        VStack(spacing: 8) {
            Button {
                startDictation()
            } label: {
                HStack {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isRecording ? .red : .blue)
                    Text(isRecording ? localized("watch_recording") : localized("watch_voice_input"))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            .buttonStyle(.plain)

            Button {
                showingContentScribble = true
            } label: {
                HStack {
                    Image(systemName: "pencil.tip")
                        .foregroundColor(.blue)
                    Text(localized("watch_handwriting"))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingContentScribble) {
            WatchScribbleInputView(
                initialText: memoText,
                titleKey: "watch_content_scribble_title",
                placeholderKey: "watch_content_placeholder"
            ) { text in
                memoText = text
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localized("watch_tags_label"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if !selectedTags.isEmpty {
                    Text(String(format: localized("watch_tags_count"), selectedTags.count, tagSelectionLimit))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if availableTags.isEmpty && customTags.isEmpty {
                Text(localized("watch_tags_empty"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 6)], spacing: 6) {
                    ForEach(availableTags, id: \.self) { tag in
                        tagChip(tag)
                    }
                    ForEach(customTags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }

            Button {
                showingTagScribble = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption)
                    Text(localized("watch_add_tag"))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedTags.count >= tagSelectionLimit)
            .opacity(selectedTags.count >= tagSelectionLimit ? 0.5 : 1)

            if selectedTags.count >= tagSelectionLimit {
                Text(String(format: localized("watch_tag_limit"), tagSelectionLimit))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingTagScribble) {
            WatchScribbleInputView(
                initialText: "",
                titleKey: "watch_tag_scribble_title",
                placeholderKey: "watch_tag_placeholder"
            ) { text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if selectedTags.count < tagSelectionLimit {
                    if !customTags.contains(trimmed) {
                        customTags.append(trimmed)
                    }
                    selectedTags.insert(trimmed)
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let isSelected = selectedTags.contains(tag)
        return Button {
            toggleTag(tag)
        } label: {
            Text(tag)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else if selectedTags.count < tagSelectionLimit {
            selectedTags.insert(tag)
        }
    }

    private var memoPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localized("watch_preview"))
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                if !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(titleText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                if !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(memoText)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                if !selectedTags.isEmpty {
                    Text(selectedTags.sorted().map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
            )
        }
    }

    private var saveButton: some View {
        Button {
            saveMemo()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(localized("watch_save"))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(canSave ? Color.blue : Color.gray)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.top, 12)
    }

    private var canSave: Bool {
        !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveMemo() {
        guard let category = selectedCategory else { return }
        let trimmedContent = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagsArray = selectedTags.sorted()
        let memoID = UUID()

        let watchMemo = WatchMemo(
            id: memoID,
            title: trimmedTitle,
            content: trimmedContent,
            category: category.name,
            createdAt: Date(),
            tags: tagsArray
        )
        dataManager.addMemo(watchMemo)

        var memoData: [String: Any] = [
            "id": memoID.uuidString,
            "title": trimmedTitle,
            "content": trimmedContent,
            "category": category.name,
            "tags": tagsArray,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let baseKey = category.baseKey {
            memoData["baseKey"] = baseKey
        }

        connectivityManager.sendMemoToPhone(memoData: memoData)
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }

    private func startDictation() {
        isRecording = true

        WKInterfaceDevice.current().play(.start)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRecording = false
            memoText = localized("watch_voice_sample")
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func localized(_ key: String) -> String {
        WatchLocalization.shared.string(for: key)
    }
}

struct WatchScribbleInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scribbleText: String
    private let titleKey: String
    private let placeholderKey: String
    private let confirmKey: String
    private let onSave: (String) -> Void

    init(initialText: String, titleKey: String, placeholderKey: String, confirmKey: String = "watch_done", onSave: @escaping (String) -> Void) {
        self._scribbleText = State(initialValue: initialText)
        self.titleKey = titleKey
        self.placeholderKey = placeholderKey
        self.confirmKey = confirmKey
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized(titleKey))
                .font(.caption)
                .padding(.bottom, 4)

            TextField(localized(placeholderKey), text: $scribbleText)
                .textFieldStyle(.automatic)

            HStack {
                Button(localized("watch_cancel")) {
                    dismiss()
                }
                .foregroundColor(.red)

                Spacer()

                Button(localized(confirmKey)) {
                    onSave(scribbleText)
                    dismiss()
                }
                .foregroundColor(.blue)
                .disabled(scribbleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding()
    }

    private func localized(_ key: String) -> String {
        WatchLocalization.shared.string(for: key)
    }
}

#Preview {
    WatchMemoInputView()
        .environmentObject(WatchConnectivityManager.shared)
}
