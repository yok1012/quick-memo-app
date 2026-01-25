# ChatGPT/Codex AI 専用実装ブランチ

ブランチ: `feature/ai-codex`
ディレクトリ: `quickMemoApp-codex/`

## 🎯 実装方針

このブランチでは、**ChatGPT/GPT-4 (OpenAI)** に特化した実装を行います。

### 使用モデル

- **GPT-4o**: メイン処理（最新、高性能）
  - タグ抽出
  - メモアレンジ
  - カテゴリー要約
- **GPT-4o-mini**: 簡単な処理（低コスト）
- **GPT-3.5 Turbo**: コスト重視の場合

### 実装の特徴

1. **OpenAI固有機能の活用**
   - Function Calling（構造化出力）
   - JSON mode
   - Structured Outputs
   - Vision（将来的に画像も）

2. **最適化ポイント**
   - System message の活用
   - Temperature チューニング
   - Max tokens 調整
   - Streaming（リアルタイム表示）

3. **コスト効率化**
   - GPT-4o-mini の活用
   - トークン最適化
   - キャッシング戦略

## 📊 ベンチマーク項目

### 1. 精度評価
- [ ] タグ抽出の適切性（関連性、網羅性）
- [ ] メモアレンジの品質（文法、スタイル、意図保持）
- [ ] カテゴリー要約の正確性（重要ポイント抽出）

### 2. パフォーマンス
- [ ] レスポンス時間（平均、最大、最小）
- [ ] トークン使用量（入力、出力）
- [ ] GPT-4o vs GPT-4o-mini のパフォーマンス比較

### 3. コスト分析
- [ ] リクエストあたりのコスト
- [ ] 月間使用量の推定コスト
- [ ] モデル別コスト比較

### 4. ユーザー体験
- [ ] 使いやすさ（主観評価）
- [ ] 結果への満足度
- [ ] エラー発生率

## 🔧 実装タスク

### Phase 1: OpenAI統合
- [ ] OpenAI SDK セットアップ
- [ ] APIキー管理（Keychain）
- [ ] 基本的なAPI呼び出し実装

### Phase 2: 機能実装
- [ ] タグ抽出機能
  - [ ] Function Calling 活用
  - [ ] JSON mode 使用
  - [ ] エラーハンドリング
- [ ] メモアレンジ機能
  - [ ] プリセット実装
  - [ ] カスタムプロンプト対応
  - [ ] Streaming 対応（リアルタイム表示）
- [ ] カテゴリー要約機能
  - [ ] 複数メモの統合
  - [ ] 構造化出力
  - [ ] トレンド分析

### Phase 3: 最適化
- [ ] GPT-4o vs mini の使い分けロジック
- [ ] トークン使用量の最適化
- [ ] バッチ処理対応

### Phase 4: ベンチマーク
- [ ] テストデータセット準備
- [ ] 自動評価スクリプト
- [ ] 結果レポート生成

## 📝 実装メモ

### OpenAI API の特徴

```swift
// OpenAI SDK 使用例
import OpenAI

let openAI = OpenAI(apiToken: apiKey)

let query = ChatQuery(
    messages: [
        .init(role: .system, content: "あなたは日本語テキストからタグを抽出する専門家です。"),
        .init(role: .user, content: "以下のメモからタグを抽出してください: \(memoContent)")
    ],
    model: .gpt4o,
    responseFormat: .jsonObject,
    temperature: 0.7,
    maxTokens: 1024
)

let result = try await openAI.chats(query: query)
```

### Function Calling（構造化出力）

```swift
let function = ChatQuery.ChatCompletionToolParam(
    function: .init(
        name: "extract_tags",
        description: "メモからタグを抽出する",
        parameters: .init(
            type: .object,
            properties: [
                "tags": .init(
                    type: .array,
                    items: .init(type: .string),
                    description: "抽出されたタグのリスト"
                )
            ],
            required: ["tags"]
        )
    )
)
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

#### メモアレンジ（Streaming対応）
```
以下の指示に従って、メモを整形してください。
元のメモの意図を保ちながら、読みやすく改善してください。

指示: {instruction}

元のメモ:
{memo_content}
```

### Streaming実装

```swift
let query = ChatQuery(
    messages: messages,
    model: .gpt4o,
    stream: true
)

for try await result in openAI.chatsStream(query: query) {
    guard let choice = result.choices.first else { continue }
    if let content = choice.delta.content {
        // リアルタイムでUIを更新
        arrangedText += content
    }
}
```

## 🎯 成功基準

1. **精度**: 他のAIと比較して同等以上
2. **速度**: 平均レスポンス時間 < 2.5秒
3. **コスト**: 月間100リクエストで $0.75以下
4. **UX**: エラー率 < 5%、Streaming対応でUX向上

## 💡 ChatGPT の強み

- **最新技術**: GPT-4o は最新の言語モデル
- **高精度**: 複雑な指示への理解が優れている
- **豊富なAPI**: Function Calling、Vision、Streaming等
- **エコシステム**: 豊富なツールとライブラリ

## 📚 参考資料

- [OpenAI Platform](https://platform.openai.com/)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [GPT-4o Documentation](https://platform.openai.com/docs/models/gpt-4o)
- [Function Calling Guide](https://platform.openai.com/docs/guides/function-calling)
- [Prompt Engineering Guide](https://platform.openai.com/docs/guides/prompt-engineering)

---

最終更新: 2025-01-25
