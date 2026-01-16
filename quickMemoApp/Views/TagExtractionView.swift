import SwiftUI

/// タグ自動抽出ビュー（メモ編集時に使用）
struct TagExtractionView: View {
    let memoContent: String
    let categoryName: String
    @Binding var selectedTags: Set<String>
    @StateObject private var aiManager = AIManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var extractedTags: [String] = []
    @State private var localSelectedTags: Set<String> = []  // ローカルで選択状態を管理
    @State private var isExtracting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isExtracting {
                    // 抽出中
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AIがタグを抽出しています...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if extractedTags.isEmpty {
                    // 初期状態
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)

                        Text("メモ内容からタグを自動抽出")
                            .font(.headline)

                        Text("Gemini AIがメモを分析し、関連するタグを提案します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: extractTags) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("タグを抽出する")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 抽出結果表示
                    List {
                        Section {
                            Text("メモ内容から以下のタグを抽出しました。追加したいタグをタップしてください。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Section("提案されたタグ") {
                            ForEach(extractedTags, id: \.self) { tag in
                                Button(action: {
                                    toggleTag(tag)
                                }) {
                                    HStack {
                                        Image(systemName: localSelectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(localSelectedTags.contains(tag) ? .green : .gray)

                                        Text("#\(tag)")
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                }
                            }
                        }

                        Section {
                            Button(action: {
                                applySelectedTags()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("選択したタグを追加 (\(localSelectedTags.count))")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                            }
                            .disabled(localSelectedTags.isEmpty)
                        }
                    }
                }

                // 使用統計フッター
                if !isExtracting {
                    usageStatsFooter
                }
            }
            .navigationTitle("タグ抽出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                if !extractedTags.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("追加") {
                            applySelectedTags()
                        }
                        .fontWeight(.semibold)
                        .disabled(localSelectedTags.isEmpty)
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            // メモ内容が短い場合は警告
            if memoContent.count < 20 {
                errorMessage = "メモの内容が短すぎます。より詳しい内容を書くと、より適切なタグが抽出できます。"
                showError = true
            }
        }
    }

    private var usageStatsFooter: some View {
        VStack(spacing: 8) {
            Divider()

            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("今月の使用: \(aiManager.usageStats.totalRequests)/\(aiManager.usageStats.monthlyLimit)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("残り: \(aiManager.usageStats.remainingRequests)")
                    .font(.caption)
                    .foregroundColor(aiManager.usageStats.isQuotaExceeded ? .red : .green)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }

    private func toggleTag(_ tag: String) {
        // ローカルの選択状態のみ変更（画面が閉じないように）
        if localSelectedTags.contains(tag) {
            localSelectedTags.remove(tag)
        } else {
            localSelectedTags.insert(tag)
        }
    }

    private func applySelectedTags() {
        // 選択されたタグを親ビューに反映
        for tag in localSelectedTags {
            selectedTags.insert(tag)
        }
        // カテゴリーにもタグを追加
        let dataManager = DataManager.shared
        for tag in localSelectedTags {
            _ = dataManager.addTag(to: categoryName, tag: tag)
        }
        dismiss()
    }

    private func extractTags() {
        isExtracting = true

        Task {
            do {
                let tags = try await aiManager.extractTags(from: memoContent)

                await MainActor.run {
                    extractedTags = tags
                    isExtracting = false
                }
            } catch {
                await MainActor.run {
                    isExtracting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    TagExtractionView(
        memoContent: "今日は会議があって、新しいプロジェクトについて話し合いました。マーケティング戦略とプロダクト開発のタイムラインを確認しました。",
        categoryName: "仕事",
        selectedTags: .constant(Set())
    )
}
