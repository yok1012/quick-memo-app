# APIキー不要AI機能 実装計画

Pro版ユーザーが自分のAPIキーを入力せずに、開発者提供のAI機能を使える仕組み

---

## 🎯 目標

- **ユーザー**: APIキー不要でAI機能利用
- **開発者**: コスト管理と不正利用防止
- **Pro版限定**: 無料版は従来通り自分のAPIキー必要

---

## 🏗️ アーキテクチャ選択肢

### 推奨: Cloud Functions（サーバーレス）

```
┌─────────────┐
│  iOS App    │
│  (Pro版)    │
└──────┬──────┘
       │ HTTPS Request
       │ + Pro Token
       ↓
┌─────────────────┐
│ Cloud Functions │
│  ├─ Auth Check  │ ← StoreKit Receipt検証
│  ├─ Rate Limit  │ ← 使用量制限
│  └─ AI Proxy    │ ← 開発者APIキー使用
└──────┬──────────┘
       │
       ↓
┌──────────────┐
│  AI APIs     │
│  - Claude    │
│  - Gemini    │
│  - ChatGPT   │
└──────────────┘
```

**技術スタック:**
- **Firebase Cloud Functions** (Node.js/TypeScript)
- **Firebase Authentication** (Proトークン発行)
- **Firestore** (使用量記録)

---

## 📝 実装フェーズ

### Phase 1: バックエンド構築（2-3日）

#### 1-1. Firebase Projectセットアップ

```bash
# Firebaseプロジェクト作成
firebase init functions

# 必要なパッケージ
npm install --save express
npm install --save @anthropic-ai/sdk
npm install --save @google/generative-ai
npm install --save openai
```

#### 1-2. Cloud Function実装

```typescript
// functions/src/index.ts
import * as functions from 'firebase-functions';
import Anthropic from '@anthropic-ai/sdk';
import { GoogleGenerativeAI } from '@google/generative-ai';
import OpenAI from 'openai';

// APIキーは環境変数で管理（安全）
const claude = new Anthropic({
  apiKey: functions.config().ai.claude_key
});

const gemini = new GoogleGenerativeAI(
  functions.config().ai.gemini_key
);

const openai = new OpenAI({
  apiKey: functions.config().ai.openai_key
});

// タグ抽出エンドポイント
export const extractTags = functions.https.onRequest(async (req, res) => {
  // 1. Pro版チェック
  const isPro = await verifyProStatus(req.body.userId, req.body.receiptData);
  if (!isPro) {
    return res.status(403).json({ error: 'Pro version required' });
  }

  // 2. 使用量チェック
  const canUse = await checkUsageLimit(req.body.userId);
  if (!canUse) {
    return res.status(429).json({ error: 'Usage limit exceeded' });
  }

  // 3. AI処理（開発者のAPIキー使用）
  const aiProvider = req.body.provider || 'gemini'; // デフォルトはコスト最安のGemini

  try {
    let tags = [];

    if (aiProvider === 'claude') {
      const response = await claude.messages.create({
        model: 'claude-3-haiku-20240307',
        max_tokens: 1024,
        messages: [{
          role: 'user',
          content: `タグを抽出: ${req.body.content}`
        }]
      });
      tags = parseTagsFromResponse(response);
    } else if (aiProvider === 'gemini') {
      const model = gemini.getGenerativeModel({ model: 'gemini-2.0-flash-exp' });
      const result = await model.generateContent(
        `タグを抽出: ${req.body.content}`
      );
      tags = parseTagsFromResponse(result);
    } else if (aiProvider === 'openai') {
      const response = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [{
          role: 'user',
          content: `タグを抽出: ${req.body.content}`
        }]
      });
      tags = parseTagsFromResponse(response);
    }

    // 4. 使用量記録
    await recordUsage(req.body.userId, aiProvider, req.body.content.length);

    return res.json({ tags });

  } catch (error) {
    console.error('AI Error:', error);
    return res.status(500).json({ error: 'AI processing failed' });
  }
});

// Pro版検証
async function verifyProStatus(userId: string, receiptData: string): Promise<boolean> {
  // StoreKit Receipt検証
  // または、アプリ側でトークンを事前取得させる方式
  return true; // TODO: 実装
}

// 使用量チェック（1ヶ月100リクエストなど）
async function checkUsageLimit(userId: string): Promise<boolean> {
  // Firestoreで使用回数をチェック
  const usage = await admin.firestore()
    .collection('usage')
    .doc(userId)
    .get();

  const monthlyLimit = 100; // Pro版の月間制限
  const currentUsage = usage.data()?.count || 0;

  return currentUsage < monthlyLimit;
}

// 使用量記録
async function recordUsage(userId: string, provider: string, inputLength: number) {
  await admin.firestore()
    .collection('usage')
    .doc(userId)
    .set({
      count: admin.firestore.FieldValue.increment(1),
      lastUsed: admin.firestore.FieldValue.serverTimestamp(),
      provider
    }, { merge: true });
}
```

#### 1-3. 環境変数設定

```bash
# APIキーを安全に設定
firebase functions:config:set ai.claude_key="sk-ant-xxx"
firebase functions:config:set ai.gemini_key="AIzaXXX"
firebase functions:config:set ai.openai_key="sk-xxx"

# デプロイ
firebase deploy --only functions
```

---

### Phase 2: iOS アプリ実装（2-3日）

#### 2-1. ProAIService作成

```swift
// quickMemoApp/Services/ProAIService.swift
import Foundation

class ProAIService {
    static let shared = ProAIService()

    // Cloud Functionsのエンドポイント
    private let baseURL = "https://YOUR-PROJECT.cloudfunctions.net"

    // Pro版AI機能: タグ抽出
    func extractTags(from content: String, provider: AIProvider = .gemini) async throws -> [String] {
        // Pro版チェック
        guard PurchaseManager.shared.isProVersion else {
            throw ProAIError.proVersionRequired
        }

        // ユーザーID取得（CloudKit User ID or Sign in with Apple）
        guard let userId = await getCurrentUserId() else {
            throw ProAIError.authenticationRequired
        }

        // Cloud Functionsにリクエスト
        var request = URLRequest(url: URL(string: "\(baseURL)/extractTags")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "content": content,
            "provider": provider.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // リクエスト実行
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProAIError.networkError
        }

        // エラーハンドリング
        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(TagsResponse.self, from: data)
            return result.tags
        case 403:
            throw ProAIError.proVersionRequired
        case 429:
            throw ProAIError.usageLimitExceeded
        default:
            throw ProAIError.serverError
        }
    }

    // ユーザーID取得
    private func getCurrentUserId() async -> String? {
        // CloudKit User IDまたはSign in with AppleのUser IDを使用
        // TODO: 実装
        return "user-id-placeholder"
    }
}

enum AIProvider: String {
    case claude = "claude"
    case gemini = "gemini"
    case openai = "openai"
}

struct TagsResponse: Codable {
    let tags: [String]
}

enum ProAIError: Error {
    case proVersionRequired
    case authenticationRequired
    case usageLimitExceeded
    case networkError
    case serverError
}
```

#### 2-2. AIManager拡張

```swift
// AIManager.swiftに追加
extension AIManager {
    /// Pro版AI機能: APIキー不要でタグ抽出
    func extractTagsWithProService(from content: String) async throws -> [String] {
        // Pro版なら開発者提供のAIを使用
        if PurchaseManager.shared.isProVersion {
            do {
                return try await ProAIService.shared.extractTags(from: content)
            } catch ProAIError.usageLimitExceeded {
                // 使用量超過時はエラー表示
                throw ProAIError.usageLimitExceeded
            } catch {
                // エラー時はフォールバック: ユーザーのAPIキーを使用
                return try await extractTags(from: content)
            }
        } else {
            // 無料版は従来通りユーザーのAPIキー必要
            return try await extractTags(from: content)
        }
    }
}
```

#### 2-3. UI更新

```swift
// AISettingsView.swiftに追加
Section(header: Text("Pro版 AI機能")) {
    if PurchaseManager.shared.isProVersion {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("APIキー不要でAI機能を利用できます")
                    .font(.subheadline)
            }

            Text("今月の使用回数: \(usageCount)/100")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    } else {
        VStack(alignment: .leading) {
            Text("Pro版にアップグレードすると、APIキー不要でAI機能を利用できます")
                .font(.subheadline)

            Button("Pro版にアップグレード") {
                // PurchaseViewを表示
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

---

### Phase 3: 使用量表示・管理（1-2日）

#### 3-1. 使用量取得API

```typescript
// Cloud Functions
export const getUsage = functions.https.onRequest(async (req, res) => {
  const userId = req.body.userId;

  const usage = await admin.firestore()
    .collection('usage')
    .doc(userId)
    .get();

  return res.json({
    count: usage.data()?.count || 0,
    limit: 100,
    remaining: 100 - (usage.data()?.count || 0)
  });
});
```

#### 3-2. iOS側で使用量表示

```swift
struct ProAIUsageView: View {
    @State private var usage: UsageStats?

    var body: some View {
        VStack {
            if let usage = usage {
                ProgressView(value: Double(usage.count), total: Double(usage.limit))
                Text("\(usage.count) / \(usage.limit) 回使用")
                Text("残り: \(usage.remaining) 回")
            }
        }
        .onAppear {
            Task {
                usage = try? await ProAIService.shared.getUsage()
            }
        }
    }
}
```

---

## 💰 コスト試算

### 月間コスト（100ユーザー想定）

| AI | 1リクエストコスト | 100回/月/ユーザー | 100ユーザー | 月間合計 |
|----|------------------|-----------------|------------|---------|
| **Gemini Flash** | $0.0001 | $0.01 | $1.00 | **$1.00** |
| **Claude Haiku** | $0.0005 | $0.05 | $5.00 | **$5.00** |
| **GPT-4o-mini** | $0.0003 | $0.03 | $3.00 | **$3.00** |

**推奨**: Gemini Flashをデフォルトに設定（最安値）

### Firebase無料枠

- **Cloud Functions**: 2百万回実行/月 無料
- **Firestore**: 5万回読み取り/月 無料
- **Hosting**: 10GB転送/月 無料

→ **初期は完全無料で運用可能**

---

## 🔐 セキュリティ

### 1. APIキー保護
- ✅ Cloud Functions内で管理（クライアントに露出しない）
- ✅ 環境変数で暗号化

### 2. 不正利用防止
- ✅ Pro版チェック（StoreKit Receipt検証）
- ✅ 使用量制限（1ヶ月100回など）
- ✅ Rate Limiting（1分10回など）

### 3. ユーザー認証
- ✅ Sign in with Apple統合
- ✅ CloudKit User ID使用

---

## 📊 実装スケジュール

| フェーズ | タスク | 所要時間 |
|---------|--------|---------|
| **Phase 1** | Firebase & Cloud Functions | 2-3日 |
| **Phase 2** | iOS アプリ実装 | 2-3日 |
| **Phase 3** | 使用量管理・UI | 1-2日 |
| **テスト** | 統合テスト | 1日 |
| **リリース** | App Store申請 | - |

**合計: 約1週間**

---

## 🚀 次のステップ

1. **Firebase Project作成**
   ```bash
   firebase init
   ```

2. **Cloud Functions実装**
   - タグ抽出エンドポイント
   - Pro版検証
   - 使用量管理

3. **iOS統合**
   - ProAIService実装
   - AIManager拡張
   - UI更新

4. **テスト**
   - Pro版動作確認
   - 使用量制限テスト
   - エラーハンドリング

---

## 💡 代替案: 直接API呼び出し（非推奨）

もしバックエンドを作りたくない場合:

```swift
// アプリに開発者のAPIキーを埋め込む（セキュリティリスク大）
let hardcodedAPIKey = "sk-ant-xxx" // ⚠️ 危険！

// Pro版ユーザーのみこのキーを使用
if PurchaseManager.shared.isProVersion {
    // 開発者のAPIキーで直接呼び出し
}
```

**問題点:**
- ❌ APIキーが露出（逆コンパイルで抜き取られる）
- ❌ 使用量制限不可（無制限に使われる）
- ❌ コスト爆発のリスク

→ **絶対に避けるべき**

---

最終更新: 2025-01-25
