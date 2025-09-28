import SwiftUI
#if os(watchOS)
import WatchKit
#endif

#if os(watchOS)
@available(watchOS 10.0, *)
struct WatchMemoInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedCategory: String = LocalizedCategories.localizedName(for: "work")
    @State private var memoText: String = ""
    @State private var isRecording = false
    @State private var showingScribble = false
    
    private var categories: [String] {
        LocalizedCategories.getDefaultCategories().map { $0.name } + [LocalizedCategories.localizedName(for: "other")]
    }
    
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
            .navigationTitle(localizationManager.localizedString(for: "quick_memo"))
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
                    Text(
                        isRecording
                        ? localizationManager.localizedString(for: "recording")
                        : localizationManager.localizedString(for: "voice_input")
                    )
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
                    Text(localizationManager.localizedString(for: "scribble_input"))
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
            Text(localizationManager.localizedString(for: "preview"))
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
                Text(localizationManager.localizedString(for: "save"))
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
        
        let options: [String: Any] = [
            WKAudioRecorderPreset: WKAudioRecorderPreset.narrowBandSpeech.rawValue
        ]
        
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
        
        WatchConnectivityManager.shared.sendMemoToPhone(memoData: memoData)
        
        WKInterfaceDevice.current().play(.success)
        
        dismiss()
    }
}

@available(watchOS 10.0, *)
struct ScribbleInputView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    @State private var scribbleText = ""
    
    var body: some View {
        VStack {
            Text(localizationManager.localizedString(for: "scribble_input"))
                .font(.caption)
                .padding(.bottom, 8)
            
            TextField(localizationManager.localizedString(for: "scribble_placeholder"), text: $scribbleText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button(localizationManager.localizedString(for: "cancel")) {
                    dismiss()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button(localizationManager.localizedString(for: "done")) {
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
    if #available(watchOS 10.0, *) {
        WatchMemoInputView()
    }
}
#endif

#if !os(watchOS)
// Placeholder structs for non-watchOS platforms
struct WatchMemoInputView: View {
    var body: some View {
        Text("Watch memo input not available on this platform")
    }
}

struct ScribbleInputView: View {
    @Binding var text: String
    
    init(text: Binding<String>) {
        _text = text
    }
    
    var body: some View {
        Text("Scribble input not available on this platform")
    }
}
#endif
