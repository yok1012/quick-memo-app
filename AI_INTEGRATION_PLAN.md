# AI統合機能 実装計画

## 目標機能

1. **タグ自動抽出**
   - メモ内容から関連タグを自動生成
   - 既存カテゴリーとの関連性を考慮

2. **メモのアレンジ**
   - ユーザー指定の指示に基づいてメモを編集
   - 例: 「ビジネス文書風に」「要約して」「英語に翻訳」

3. **カテゴリー別要約・要点抽出**
   - カテゴリー内の全メモを分析
   - 要約、要点、トレンドを抽出

## API選定とコスト比較

### Claude API (Anthropic)
- **モデル**: Claude 3.5 Haiku
- **料金**: $0.80/1M input tokens, $4.00/1M output tokens
- **特徴**: 日本語に強い、コンテキスト理解が優秀
- **推奨用途**: メモアレンジ、要約

### Gemini API (Google)
- **モデル**: Gemini 1.5 Flash
- **料金**: 無料枠あり（15 RPM）、有料は$0.075/1M tokens
- **特徴**: 最もコスト効率が良い
- **推奨用途**: タグ抽出（シンプルなタスク）

### OpenAI API (ChatGPT)
- **モデル**: GPT-4o-mini
- **料金**: $0.150/1M input tokens, $0.600/1M output tokens
- **特徴**: バランスが良い
- **推奨用途**: 汎用的なタスク

## コスト見積もり

### タグ抽出（1回あたり）
- 入力: 約200トークン（メモ本文）
- 出力: 約50トークン（タグリスト）
- **Gemini Flash**: 無料枠内
- **Claude Haiku**: 約$0.0002

### メモアレンジ（1回あたり）
- 入力: 約300トークン（メモ + 指示）
- 出力: 約200トークン（編集後メモ）
- **Claude Haiku**: 約$0.001

### カテゴリー要約（1回あたり）
- 入力: 約2000トークン（50件のメモ）
- 出力: 約300トークン（要約）
- **Claude Haiku**: 約$0.003

**月間コスト試算**:
- タグ抽出: 100回 → 無料（Gemini）
- メモアレンジ: 20回 → $0.02
- カテゴリー要約: 10回 → $0.03
- **合計: 約$0.05/月（約7円）**

## アーキテクチャ設計

```
┌─────────────────┐
│   QuickMemo App │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼───┐
│Gemini│  │Claude│
│ API  │  │ API  │
└──────┘  └──────┘
```

### コンポーネント構成

```
Services/
├── AIManager.swift          # AI機能の統合管理
├── GeminiService.swift      # Gemini API連携
├── ClaudeService.swift      # Claude API連携
├── OpenAIService.swift      # OpenAI API連携（オプション）
└── AIUsageTracker.swift     # 使用量・コスト追跡

Models/
├── AIRequest.swift          # リクエストモデル
├── AIResponse.swift         # レスポンスモデル
└── AIUsageStats.swift       # 使用統計

Views/
├── AIFeaturesView.swift     # AI機能UI
├── TagSuggestionView.swift  # タグ提案UI
├── MemoArrangeView.swift    # メモアレンジUI
└── CategorySummaryView.swift # カテゴリー要約UI
```

## 実装フェーズ

### Phase 1: 基盤構築（1週間）
- [ ] AIManager基本構造
- [ ] APIキー管理（KeychainまたはUserDefaults暗号化）
- [ ] ネットワーク層実装
- [ ] エラーハンドリング

### Phase 2: タグ自動抽出（Gemini）
- [ ] GeminiService実装
- [ ] タグ抽出プロンプト設計
- [ ] UI実装
- [ ] テスト

### Phase 3: メモアレンジ（Claude）
- [ ] ClaudeService実装
- [ ] アレンジプロンプト設計
- [ ] プリセット機能（要約、ビジネス化、翻訳など）
- [ ] UI実装

### Phase 4: カテゴリー要約
- [ ] バッチ処理実装
- [ ] 要約生成
- [ ] エクスポート機能
- [ ] UI実装

### Phase 5: コスト管理
- [ ] 使用量トラッキング
- [ ] 月次制限設定
- [ ] 使用統計表示
- [ ] アラート機能

## セキュリティ対策

### APIキー管理
```swift
// Keychainに暗号化して保存
// Pro版ユーザーのみ利用可能
// 環境変数からの読み込みをサポート
```

### データプライバシー
- メモ内容はAPIに送信される前に確認
- ユーザー同意取得
- データは保存されない（APIプロバイダー依存）

## Pro版機能として実装

### Free版
- タグ抽出: 月5回まで
- メモアレンジ: 利用不可
- カテゴリー要約: 利用不可

### Pro版
- タグ抽出: 月100回まで
- メモアレンジ: 月20回まで
- カテゴリー要約: 月10回まで
- 使用統計閲覧可能

## 技術スタック

- **ネットワーク**: URLSession + async/await
- **JSON処理**: Codable
- **UI**: SwiftUI
- **キャッシュ**: UserDefaults（使用統計）
- **セキュア保存**: Keychain（APIキー）

## 次のステップ

1. APIキー取得（Gemini, Claude）
2. 基本的なネットワーク層実装
3. タグ抽出機能のプロトタイプ作成
4. コスト追跡機能の実装
5. UI/UX設計

## 参考リンク

- [Gemini API Documentation](https://ai.google.dev/docs)
- [Claude API Documentation](https://docs.anthropic.com/)
- [OpenAI API Documentation](https://platform.openai.com/docs/)
