import SwiftUI
import WatchKit

struct WatchFastInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @StateObject private var dataManager = WatchDataManager.shared
    @StateObject private var purchaseManager = WatchPurchaseManager.shared

    @State private var selectedCategory: String = "仕事"
    @State private var memoTitle: String = ""
    @State private var memoText: String = ""
    @State private var showingVoiceInput = false
    @State private var showingTextInput = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categorySelector
                
                if !memoText.isEmpty {
                    memoPreview
                }
                
                inputButtons
                
                saveButton
            }
            .navigationTitle("Quick Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                WatchCategorySettingsView()
            }
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(getAvailableCategories(), id: \.id) { category in
                    Button(action: {
                        selectedCategory = category.name
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                            Text(category.name)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selectedCategory == category.name ? .white : .primary)
                        .frame(width: 60, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedCategory == category.name ?
                                    Color(hex: category.color) : Color(.darkGray))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
    
    private var memoPreview: some View {
        ScrollView {
            Text(memoText)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.darkGray))
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private var inputButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                showingVoiceInput = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                    Text("音声")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                showingTextInput = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20))
                    Text("テキスト")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView(text: $memoText)
        }
        .sheet(isPresented: $showingTextInput) {
            WatchTextInputView(text: $memoText)
        }
    }
    
    private var saveButton: some View {
        Button(action: saveMemo) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("保存")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(memoText.isEmpty ? Color.gray : Color.green)
            )
        }
        .disabled(memoText.isEmpty)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .buttonStyle(PlainButtonStyle())
    }
    
    private func saveMemo() {
        guard !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Save locally first
        let watchMemo = WatchMemo(
            title: memoTitle,
            content: memoText,
            category: selectedCategory,
            createdAt: Date(),
            tags: []
        )
        dataManager.addMemo(watchMemo)

        // Then send to phone
        let memoData: [String: Any] = [
            "id": watchMemo.id.uuidString,
            "title": memoTitle,
            "content": memoText,
            "category": selectedCategory,
            "tags": [],
            "timestamp": Date().timeIntervalSince1970
        ]

        connectivityManager.sendMemoToPhone(memoData: memoData)

        WKInterfaceDevice.current().play(.success)
        dismiss()
    }

    private func getAvailableCategories() -> [WatchCategory] {
        if purchaseManager.isPro {
            // Pro版：iPhoneで選択したカテゴリーを表示
            if let sharedDefaults = UserDefaults(suiteName: "group.yokAppDev.quickMemoApp"),
               let selectedNames = sharedDefaults.array(forKey: "watchSelectedCategories") as? [String] {
                return dataManager.categories.filter { selectedNames.contains($0.name) }
            }
            // デフォルトで最初の4つ
            return Array(dataManager.categories.prefix(4))
        } else {
            // 無料版：デフォルトカテゴリーのみ
            return [
                WatchCategory(name: "仕事", icon: "briefcase", color: "007AFF"),
                WatchCategory(name: "プライベート", icon: "house", color: "34C759"),
                WatchCategory(name: "その他", icon: "folder", color: "8E8E93")
            ]
        }
    }
}

struct VoiceInputView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("音声入力")
                .font(.system(size: 16, weight: .semibold))
            
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 40))
                .foregroundColor(isRecording ? .red : .blue)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
            
            Text(isRecording ? "話してください..." : "タップして開始")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button(action: {
                // 実際の音声認識実装が必要
                // ここではデモテキストを設定
                text = "音声入力のテストメモです"
                dismiss()
            }) {
                Text("完了")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                    )
            }
        }
        .padding()
        .onAppear {
            isRecording = true
        }
    }
}

struct WatchTextInputView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("テキスト入力")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.top, 8)

                Text("手書き(Scribble)またはキーボードで入力")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // watchOSの標準テキストフィールド（Scribbleとキーボード両方対応）
                TextField("メモを入力...", text: $inputText, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3...6)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.darkGray))
                    )
                    .padding(.horizontal)

                // 既存テキストがある場合の表示
                if !text.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("現在のメモ:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                Spacer()

                // ボタン
                HStack(spacing: 8) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("キャンセル")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }

                    Button(action: {
                        if !inputText.isEmpty {
                            text = text.isEmpty ? inputText : text + "\n" + inputText
                        }
                        dismiss()
                    }) {
                        Text("完了")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(inputText.isEmpty ? Color.gray : Color.blue)
                            )
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .onAppear {
            inputText = text
        }
    }
}

#Preview {
    WatchFastInputView()
        .environmentObject(WatchConnectivityManager.shared)
}
