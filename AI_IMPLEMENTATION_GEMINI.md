# Gemini AI 専用実装ブランチ

ブランチ: `feature/ai-gemini`
ディレクトリ: `quickMemoApp-gemini/`

## 🎯 実装方針

このブランチでは、**Gemini AI (Google)** に特化した実装を行います。

### 使用モデル

- **Gemini 2.0 Flash**: メイン処理（高速・低コスト）
  - タグ抽出
  - メモアレンジ
  - カテゴリー要約
- **Gemini 1.5 Pro**: 複雑な処理が必要な場合

### 実装の特徴

1. **Gemini固有機能の活用**
   - 超長文コンテキスト（2M tokens）
   - マルチモーダル対応（将来的に画像も）
   - Function Calling
   - Native tool use

2. **最適化ポイント**
   - Safety Settings の調整
   - Temperature/Top-k/Top-p チューニング
   - Grounding with Google Search（オプション）
   - JSON mode の活用

3. **コスト効率化**
   - Flash モデルの活用（最安値）
   - バッチ処理
   - キャッシング戦略

## 📊 ベンチマーク項目

### 1. 精度評価
- [ ] タグ抽出の適切性（関連性、網羅性）
- [ ] メモアレンジの品質（文法、スタイル、意図保持）
- [ ] カテゴリー要約の正確性（重要ポイント抽出）

### 2. パフォーマンス
- [ ] レスポンス時間（平均、最大、最小）
- [ ] トークン使用量（入力、出力）
- [ ] Flash vs Pro のパフォーマンス比較

### 3. コスト分析
- [ ] リクエストあたりのコスト
- [ ] 月間使用量の推定コスト
- [ ] 無料枠の活用度

### 4. ユーザー体験
- [ ] 使いやすさ（主観評価）
- [ ] 結果への満足度
- [ ] エラー発生率

## 🔧 実装タスク

### Phase 1: Gemini統合
- [ ] Google AI SDK セットアップ
- [ ] APIキー管理（Keychain）
- [ ] 基本的なAPI呼び出し実装

### Phase 2: 機能実装
- [ ] タグ抽出機能
  - [ ] プロンプト最適化
  - [ ] JSON mode 活用
  - [ ] Safety Settings 調整
- [ ] メモアレンジ機能
  - [ ] プリセット実装
  - [ ] カスタムプロンプト対応
  - [ ] 結果プレビュー
- [ ] カテゴリー要約機能
  - [ ] 複数メモの統合
  - [ ] 構造化出力
  - [ ] トレンド分析

### Phase 3: 最適化
- [ ] Flash vs Pro の使い分けロジック
- [ ] Generation Config チューニング
- [ ] バッチ処理対応

### Phase 4: ベンチマーク
- [ ] テストデータセット準備
- [ ] 自動評価スクリプト
- [ ] 結果レポート生成

## 📝 実装メモ

### Gemini API の特徴

```swift
// Google AI SDK 使用例
import GoogleGenerativeAI

let model = GenerativeModel(
    name: "gemini-2.0-flash-exp",
    apiKey: apiKey,
    generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.8,
        topK: 40,
        maxOutputTokens: 1024,
        responseMimeType: "application/json"
    )
)

let response = try await model.generateContent(prompt)
```

### プロンプトテンプレート

#### タグ抽出
```
以下のメモから、内容を表す適切なタグを3-5個抽出してください。
タグは簡潔で、検索しやすい日本語の単語を選んでください。

メモ内容:
{memo_content}

JSON形式で出力:
{"tags": ["タグ1", "タグ2", "タグ3"]}
```

#### メモアレンジ
```
以下の指示に従って、メモを整形してください。
元のメモの意図を保ちながら、読みやすく改善してください。

指示: {instruction}

元のメモ:
{memo_content}

整形後のメモのみを出力してください。
```

### Safety Settings

```swift
let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockOnlyHigh),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockOnlyHigh),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockOnlyHigh),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockOnlyHigh)
]
```

## 🎯 成功基準

1. **精度**: 他のAIと比較して同等以上
2. **速度**: 平均レスポンス時間 < 2秒（Flash使用時）
3. **コスト**: 月間100リクエストで $0.50以下
4. **UX**: エラー率 < 5%

## 💡 Gemini の強み

- **最安値**: Flash モデルは最もコスト効率が良い
- **高速**: Flash は最速のレスポンス
- **大容量**: 2M tokens のコンテキスト
- **無料枠**: 月15 RPM まで無料

## 📚 参考資料

- [Google AI Studio](https://makersuite.google.com/)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [Gemini Models](https://ai.google.dev/models/gemini)
- [Prompt Design Best Practices](https://ai.google.dev/docs/prompt_best_practices)

---

最終更新: 2025-01-25
