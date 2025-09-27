import SwiftUI
import WatchKit

struct WatchFastInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @StateObject private var dataManager = WatchDataManager.shared

    @State private var selectedCategory: String = "仕事"
    @State private var memoTitle: String = ""
    @State private var memoText: String = ""
    @State private var showingVoiceInput = false
    @State private var showingScribble = false
    
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
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dataManager.categories) { category in
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
                showingScribble = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "scribble")
                        .font(.system(size: 20))
                    Text("手書き")
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
        .sheet(isPresented: $showingScribble) {
            WatchScribbleInputView(text: $memoText)
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
            category: selectedCategory
        )
        dataManager.addMemo(watchMemo)

        // Then send to phone
        let memoData: [String: Any] = [
            "id": watchMemo.id.uuidString,
            "title": memoTitle,
            "content": memoText,
            "category": selectedCategory,
            "timestamp": Date().timeIntervalSince1970
        ]

        connectivityManager.sendMemoToPhone(memoData: memoData)

        WKInterfaceDevice.current().play(.success)
        dismiss()
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

struct WatchScribbleInputView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("手書き入力")
                .font(.system(size: 16, weight: .semibold))
            
            TextField("ここに書く...", text: $text)
                .font(.system(size: 14))
                .textFieldStyle(.automatic)
            
            Button(action: {
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
    }
}

#Preview {
    WatchFastInputView()
        .environmentObject(WatchConnectivityManager.shared)
}