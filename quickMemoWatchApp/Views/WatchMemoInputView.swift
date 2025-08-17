import SwiftUI
import WatchKit

struct WatchMemoInputView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @State private var selectedCategory: String = "仕事"
    @State private var memoText: String = ""
    @State private var isRecording = false
    @State private var showingScribble = false
    
    private let categories = ["仕事", "プライベート", "アイデア", "人物", "その他"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                categorySelector
                
                inputMethods
                
                if !memoText.isEmpty {
                    memoPreview
                }
                
                Spacer()
                
                if !memoText.isEmpty {
                    saveButton
                }
            }
            .padding(.horizontal, 8)
            .navigationTitle("Quick Memo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(.caption2)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedCategory == category ? Color.blue : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var inputMethods: some View {
        VStack(spacing: 8) {
            Button(action: {
                startDictation()
            }) {
                HStack {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isRecording ? .red : .blue)
                    Text(isRecording ? "録音中..." : "音声入力")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingScribble = true
            }) {
                HStack {
                    Image(systemName: "pencil.tip")
                        .foregroundColor(.blue)
                    Text("手書き入力")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingScribble) {
            ScribbleInputView(text: $memoText)
        }
    }
    
    private var memoPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("プレビュー")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(memoText)
                .font(.caption)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                .lineLimit(3)
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            saveMemo()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("保存")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startDictation() {
        isRecording = true
        
        WKInterfaceDevice.current().play(.start)
        
        presentInputController(withSuggestions: nil, allowedInputMode: .plain) { results in
            isRecording = false
            
            if let text = results?.first as? String, !text.isEmpty {
                memoText = text
                WKInterfaceDevice.current().play(.success)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
    
    private func saveMemo() {
        let memoData: [String: Any] = [
            "content": memoText,
            "category": selectedCategory,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        connectivityManager.sendMemoToPhone(memoData: memoData)
        
        WKInterfaceDevice.current().play(.success)
        
        dismiss()
    }
}

struct ScribbleInputView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    @State private var scribbleText = ""
    
    var body: some View {
        VStack {
            Text("手書きで入力")
                .font(.caption)
                .padding(.bottom, 8)
            
            TextField("ここに書いてください", text: $scribbleText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("完了") {
                    text = scribbleText
                    dismiss()
                }
                .foregroundColor(.blue)
                .disabled(scribbleText.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

#Preview {
    WatchMemoInputView()
        .environmentObject(WatchConnectivityManager.shared)
}