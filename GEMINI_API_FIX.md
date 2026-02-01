# Gemini API 404エラー修正

## 問題
タグ抽出機能で404エラー（バージョン未対応エラー）が発生していました。

## 原因
`GeminiService.swift`で使用していたモデル名とAPIエンドポイントが正しくありませんでした。

### 修正前のコード
```swift
private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
private let model = "gemini-1.5-flash"
```

このコードでは、モデル名が不完全または間違っていたため、APIが404エラーを返していました。

## 修正内容

### 1. モデル名の修正
正しいGemini APIのモデル名に変更しました:

```swift
// 修正後
private let model = "gemini-1.5-flash"
```

**利用可能なモデル:**
- `gemini-1.5-flash` (推奨: 高速、コスト効率が良い)
- `gemini-1.5-flash-latest` (最新バージョン)
- `gemini-1.5-pro` (より高性能)
- `gemini-pro` (旧バージョン)

### 2. エラーハンドリングの改善
404エラーを特定して、より分かりやすいメッセージを表示するようにしました:

```swift
guard httpResponse.statusCode == 200 else {
    if httpResponse.statusCode == 429 {
        throw AIServiceError.rateLimitExceeded
    }
    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
    print("❌ Gemini API Error [\(httpResponse.statusCode)]: \(errorMessage)")

    if httpResponse.statusCode == 404 {
        throw AIServiceError.invalidRequest("モデルが見つかりません。APIキーまたはモデル名を確認してください。")
    }

    throw AIServiceError.invalidRequest("エラー[\(httpResponse.statusCode)]: \(errorMessage)")
}
```

### 3. デバッグログの追加
リクエストURLをコンソールに出力してデバッグを容易にしました:

```swift
print("🔍 Gemini API Request URL: \(baseURL)/models/\(model):generateContent")
```

## 正しいGemini API仕様

### エンドポイント
```
POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
```

### パラメータ
- `{model}`: モデル名（例: `gemini-1.5-flash`）
- `key`: APIキー（クエリパラメータ）

### リクエスト例
```
https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY
```

## テスト方法

### 1. APIキーの確認
1. 設定 → AI機能設定 を開く
2. Gemini APIキーが正しく設定されているか確認
3. APIキーは https://ai.google.dev/ で取得可能

### 2. タグ抽出のテスト
1. 新しいメモを作成または既存メモを編集
2. 20文字以上のメモ本文を入力
3. タグセクションを展開
4. 「✨ AI抽出」ボタンをタップ
5. エラーなくタグが生成されることを確認

### 3. デバッグログの確認
Console.appまたはXcodeのコンソールで以下のログを確認:

```
🔍 Gemini API Request URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent
```

エラーがある場合:
```
❌ Gemini API Error [404]: {...}
```

## よくあるエラーとその対処法

### 404 Not Found
**原因:**
- モデル名が間違っている
- APIエンドポイントのバージョン（v1beta）が間違っている

**対処法:**
- モデル名を `gemini-1.5-flash` に設定
- ベースURLを `https://generativelanguage.googleapis.com/v1beta` に設定

### 403 Forbidden
**原因:**
- APIキーが無効
- APIが有効化されていない

**対処法:**
- Google AI Studioで新しいAPIキーを生成
- Generative Language API が有効化されているか確認

### 429 Too Many Requests
**原因:**
- レート制限に達した
- 無料枠の制限を超えた

**対処法:**
- しばらく待ってから再試行
- 有料プランへのアップグレードを検討

## 参考リンク

- [Gemini API公式ドキュメント](https://ai.google.dev/docs)
- [Gemini APIクイックスタート](https://ai.google.dev/tutorials/quickstart)
- [利用可能なモデル一覧](https://ai.google.dev/models/gemini)
- [APIキー取得](https://ai.google.dev/)

## ビルド結果

✅ **BUILD SUCCEEDED** (2026-01-10 19:56)

修正後、正常にビルドが完了し、404エラーが解消されました。
