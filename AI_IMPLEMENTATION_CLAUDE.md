# Claude AI 専用実装ブランチ

ブランチ: `feature/ai-claude`
ディレクトリ: `quickMemoApp-claude/`

## 🎯 実装方針

このブランチでは、**Claude AI (Anthropic)** に特化した実装を行います。

### 使用モデル

- **Claude 3.5 Sonnet**: メイン処理
  - タグ抽出
  - メモアレンジ
  - カテゴリー要約
- **Claude 3 Haiku**: 高速処理が必要な場合

### 実装の特徴

1. **Claude固有機能の活用**
   - 長文コンテキスト対応（200k tokens）
   - 高精度な日本語処理
   - ツール使用（function calling）
   - コンテキストキャッシング

2. **最適化ポイント**
   - プロンプトエンジニアリング
   - システムプロンプトの活用
   - Few-shot learning
   - Chain of Thought推論

3. **コスト効率化**
   - Prompt Caching の活用
   - モデル使い分け（Sonnet vs Haiku）
   - バッチ処理

## 📊 ベンチマーク項目

### 1. 精度評価
- [ ] タグ抽出の適切性（関連性、網羅性）
- [ ] メモアレンジの品質（文法、スタイル、意図保持）
- [ ] カテゴリー要約の正確性（重要ポイント抽出）

### 2. パフォーマンス
- [ ] レスポンス時間（平均、最大、最小）
- [ ] トークン使用量（入力、出力）
- [ ] キャッシュヒット率

### 3. コスト分析
- [ ] リクエストあたりのコスト
- [ ] 月間使用量の推定コスト
- [ ] キャッシング適用後のコスト削減率

### 4. ユーザー体験
- [ ] 使いやすさ（主観評価）
- [ ] 結果への満足度
- [ ] エラー発生率

## 🔧 実装タスク

### Phase 1: Claude統合
- [ ] Anthropic SDK セットアップ
- [ ] APIキー管理（Keychain）
- [ ] 基本的なAPI呼び出し実装

### Phase 2: 機能実装
- [ ] タグ抽出機能
  - [ ] プロンプト最適化
  - [ ] レスポンスパース処理
  - [ ] エラーハンドリング
- [ ] メモアレンジ機能
  - [ ] プリセット実装
  - [ ] カスタムプロンプト対応
  - [ ] 結果プレビュー
- [ ] カテゴリー要約機能
  - [ ] 複数メモの統合
  - [ ] 構造化出力
  - [ ] トレンド分析

### Phase 3: 最適化
- [ ] Prompt Caching 実装
- [ ] モデル使い分けロジック
- [ ] バッチ処理対応

### Phase 4: ベンチマーク
- [ ] テストデータセット準備
- [ ] 自動評価スクリプト
- [ ] 結果レポート生成

## 📝 実装メモ

### Claude API の特徴

```swift
// Anthropic SDK 使用例
import Anthropic

let client = AnthropicClient(apiKey: apiKey)

let message = try await client.messages.create(
    model: "claude-3-5-sonnet-20241022",
    maxTokens: 1024,
    messages: [
        .init(role: .user, content: .text("タグを抽出してください: \(memoContent)"))
    ],
    system: "あなたは日本語テキストからタグを抽出する専門家です。"
)
```

### プロンプトテンプレート

#### タグ抽出
```
あなたは日本語のメモからタグを抽出する専門家です。

以下のメモから、内容を表す適切なタグを3-5個抽出してください。
タグは簡潔で、検索しやすい単語を選んでください。

メモ内容:
{memo_content}

JSON形式で出力してください:
{"tags": ["タグ1", "タグ2", "タグ3"]}
```

#### メモアレンジ
```
あなたは日本語テキストを整形する専門家です。

以下の指示に従ってメモを整形してください:
{instruction}

元のメモ:
{memo_content}

整形後のメモのみを出力してください。
```

## 🎯 成功基準

1. **精度**: 他のAIと比較して同等以上
2. **速度**: 平均レスポンス時間 < 3秒
3. **コスト**: 月間100リクエストで $1以下
4. **UX**: エラー率 < 5%

## 📚 参考資料

- [Anthropic API Documentation](https://docs.anthropic.com/)
- [Claude Prompt Engineering](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)
- [Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)

---

最終更新: 2025-01-25
