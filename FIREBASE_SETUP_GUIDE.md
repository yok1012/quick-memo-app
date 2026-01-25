# Firebase セットアップ & 実装ガイド

Pro版ユーザー向けAPIキー不要AI機能のバックエンド実装

---

## 📋 実装すべき機能仕様

### 1. エンドポイント一覧

| エンドポイント | メソッド | 機能 | Pro版必須 |
|--------------|---------|------|----------|
| `/extractTags` | POST | タグ抽出 | ✅ |
| `/arrangeMemo` | POST | メモアレンジ | ✅ |
| `/summarizeCategory` | POST | カテゴリー要約 | ✅ |
| `/getUsage` | POST | 使用量取得 | ✅ |
| `/verifyPurchase` | POST | Pro版検証 | ❌ |

### 2. 認証・制限仕様

| 項目 | 仕様 |
|-----|------|
| **認証方式** | ユーザーID（CloudKit User ID） |
| **Pro版検証** | StoreKit Receipt検証 or トークンベース |
| **月間使用量制限** | 100リクエスト/月 |
| **Rate Limit** | 10リクエスト/分 |
| **タイムアウト** | 30秒 |

### 3. コスト管理

| AI | 使用モデル | コスト/1000リクエスト |
|----|----------|---------------------|
| **Gemini** | gemini-2.0-flash-exp | $0.10 |
| **Claude** | claude-3-haiku-20240307 | $0.50 |
| **ChatGPT** | gpt-4o-mini | $0.30 |

**デフォルト**: Gemini（最安値）

---

## 🚀 ステップバイステップ実装

### Step 1: Firebaseプロジェクト作成

#### 1-1. Firebase Consoleでプロジェクト作成

1. https://console.firebase.google.com にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名: `quickmemo-ai`（または任意）
4. Google Analytics: 有効化（推奨）
5. 「プロジェクトを作成」

#### 1-2. 料金プランをBlaze（従量課金）にアップグレード

**重要**: Cloud Functionsを使用するには必須

1. Firebase Console > 左下の歯車アイコン > 使用量と請求額
2. 「詳細と設定」> 「プランを変更」
3. 「Blazeプランにアップグレード」

**無料枠（毎月）**:
- Cloud Functions: 200万回実行
- Firestore: 5万回読み取り、2万回書き込み
- Cloud Storage: 5GB

→ **初期は完全無料で運用可能**

---

### Step 2: Firebase CLI セットアップ

```bash
# Node.js インストール確認（v16以上必須）
node --version  # v16.x.x 以上

# Firebase CLI インストール
npm install -g firebase-tools

# バージョン確認
firebase --version

# Firebase ログイン
firebase login

# ログイン成功確認
firebase projects:list
```

---

### Step 3: プロジェクト初期化

```bash
# プロジェクトディレクトリ作成
mkdir quickmemo-firebase
cd quickmemo-firebase

# Firebase初期化
firebase init

# 選択肢:
# ◉ Functions: Configure and deploy Cloud Functions
# ◉ Firestore: Deploy rules and create indexes for Firestore
# (スペースで選択、Enterで確定)

# プロジェクト選択:
# → Use an existing project
# → quickmemo-ai (先ほど作成したプロジェクト)

# Functions設定:
# ? What language would you like to use?
# → TypeScript

# ? Do you want to use ESLint?
# → Yes

# ? Do you want to install dependencies with npm now?
# → Yes

# Firestore設定:
# ? What file should be used for Firestore Rules?
# → (デフォルトのまま Enter)

# ? What file should be used for Firestore indexes?
# → (デフォルトのまま Enter)
```

プロジェクト構造:
```
quickmemo-firebase/
├── functions/
│   ├── src/
│   │   └── index.ts       # Cloud Functions コード
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules         # Firestoreセキュリティルール
├── firestore.indexes.json
└── firebase.json
```

---

### Step 4: 依存パッケージインストール

```bash
cd functions

# AI SDKをインストール
npm install @anthropic-ai/sdk
npm install @google/generative-ai
npm install openai

# 型定義
npm install --save-dev @types/node

# Express（オプション: REST APIとして使う場合）
npm install express
npm install --save-dev @types/express

# パッケージ確認
cat package.json
```

---

### Step 5: Cloud Functions実装

#### 5-1. メインコード (functions/src/index.ts)

```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenerativeAI } from "@google/generative-ai";
import OpenAI from "openai";

// Firebase Admin初期化
admin.initializeApp();

// Firestoreインスタンス
const db = admin.firestore();

// AI クライアント初期化（環境変数から取得）
const getClaudeClient = () => {
  const apiKey = functions.config().ai?.claude_key;
  if (!apiKey) throw new Error("Claude API key not configured");
  return new Anthropic({ apiKey });
};

const getGeminiClient = () => {
  const apiKey = functions.config().ai?.gemini_key;
  if (!apiKey) throw new Error("Gemini API key not configured");
  return new GoogleGenerativeAI(apiKey);
};

const getOpenAIClient = () => {
  const apiKey = functions.config().ai?.openai_key;
  if (!apiKey) throw new Error("OpenAI API key not configured");
  return new OpenAI({ apiKey });
};

// ====================================
// 共通: 使用量チェック
// ====================================
async function checkUsageLimit(userId: string): Promise<{ allowed: boolean; current: number; limit: number }> {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  const usageDoc = await db
    .collection("usage")
    .doc(userId)
    .collection("monthly")
    .doc(currentMonth)
    .get();

  const monthlyLimit = 100; // Pro版の月間制限
  const currentUsage = usageDoc.exists ? (usageDoc.data()?.count || 0) : 0;

  return {
    allowed: currentUsage < monthlyLimit,
    current: currentUsage,
    limit: monthlyLimit,
  };
}

// ====================================
// 共通: 使用量記録
// ====================================
async function recordUsage(
  userId: string,
  functionName: string,
  provider: string,
  inputTokens: number,
  outputTokens: number,
  cost: number
) {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  // 月間使用量カウント
  await db
    .collection("usage")
    .doc(userId)
    .collection("monthly")
    .doc(currentMonth)
    .set(
      {
        count: admin.firestore.FieldValue.increment(1),
        lastUsed: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  // 詳細ログ
  await db.collection("usage_logs").add({
    userId,
    functionName,
    provider,
    inputTokens,
    outputTokens,
    cost,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ====================================
// エンドポイント1: タグ抽出
// ====================================
export const extractTags = functions
  .region("asia-northeast1") // 東京リージョン
  .https.onRequest(async (req, res) => {
    // CORS対応
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send("");
    }

    try {
      const { userId, content, provider = "gemini" } = req.body;

      // バリデーション
      if (!userId || !content) {
        return res.status(400).json({ error: "Missing required fields: userId, content" });
      }

      // 使用量チェック
      const usage = await checkUsageLimit(userId);
      if (!usage.allowed) {
        return res.status(429).json({
          error: "Monthly usage limit exceeded",
          current: usage.current,
          limit: usage.limit,
        });
      }

      // AI処理
      let tags: string[] = [];
      let inputTokens = 0;
      let outputTokens = 0;
      let cost = 0;

      if (provider === "claude") {
        const claude = getClaudeClient();
        const message = await claude.messages.create({
          model: "claude-3-haiku-20240307",
          max_tokens: 1024,
          messages: [
            {
              role: "user",
              content: `以下のメモから、内容を表す適切なタグを3-5個抽出してください。
タグは簡潔で、検索しやすい日本語の単語を選んでください。

メモ内容:
${content}

JSON形式で出力:
{"tags": ["タグ1", "タグ2", "タグ3"]}`,
            },
          ],
        });

        const responseText = message.content[0].type === "text" ? message.content[0].text : "";
        const jsonMatch = responseText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0]);
          tags = parsed.tags || [];
        }

        inputTokens = message.usage.input_tokens;
        outputTokens = message.usage.output_tokens;
        cost = (inputTokens * 0.00025 + outputTokens * 0.00125) / 1000;
      } else if (provider === "gemini") {
        const gemini = getGeminiClient();
        const model = gemini.getGenerativeModel({
          model: "gemini-2.0-flash-exp",
          generationConfig: {
            responseMimeType: "application/json",
          },
        });

        const result = await model.generateContent(
          `以下のメモから、内容を表す適切なタグを3-5個抽出してください。
JSON形式で出力: {"tags": ["タグ1", "タグ2", "タグ3"]}

メモ内容:
${content}`
        );

        const responseText = result.response.text();
        const parsed = JSON.parse(responseText);
        tags = parsed.tags || [];

        // Geminiは正確なトークン数取得が難しいため推定
        inputTokens = Math.ceil(content.length / 4);
        outputTokens = Math.ceil(responseText.length / 4);
        cost = (inputTokens * 0.000075 + outputTokens * 0.0003) / 1000;
      } else if (provider === "openai") {
        const openai = getOpenAIClient();
        const completion = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          messages: [
            {
              role: "user",
              content: `以下のメモから、内容を表す適切なタグを3-5個抽出してください。
JSON形式で出力: {"tags": ["タグ1", "タグ2", "タグ3"]}

メモ内容:
${content}`,
            },
          ],
          response_format: { type: "json_object" },
        });

        const responseText = completion.choices[0].message.content || "{}";
        const parsed = JSON.parse(responseText);
        tags = parsed.tags || [];

        inputTokens = completion.usage?.prompt_tokens || 0;
        outputTokens = completion.usage?.completion_tokens || 0;
        cost = (inputTokens * 0.00015 + outputTokens * 0.0006) / 1000;
      }

      // 使用量記録
      await recordUsage(userId, "extractTags", provider, inputTokens, outputTokens, cost);

      return res.json({
        tags,
        usage: {
          current: usage.current + 1,
          limit: usage.limit,
          remaining: usage.limit - usage.current - 1,
        },
      });
    } catch (error) {
      console.error("extractTags error:", error);
      return res.status(500).json({
        error: "AI processing failed",
        details: error instanceof Error ? error.message : String(error),
      });
    }
  });

// ====================================
// エンドポイント2: メモアレンジ
// ====================================
export const arrangeMemo = functions
  .region("asia-northeast1")
  .https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send("");
    }

    try {
      const { userId, content, instruction, provider = "gemini" } = req.body;

      if (!userId || !content || !instruction) {
        return res.status(400).json({
          error: "Missing required fields: userId, content, instruction",
        });
      }

      const usage = await checkUsageLimit(userId);
      if (!usage.allowed) {
        return res.status(429).json({
          error: "Monthly usage limit exceeded",
          current: usage.current,
          limit: usage.limit,
        });
      }

      let arrangedText = "";
      let inputTokens = 0;
      let outputTokens = 0;
      let cost = 0;

      const prompt = `以下の指示に従って、メモを整形してください。
元のメモの意図を保ちながら、読みやすく改善してください。

指示: ${instruction}

元のメモ:
${content}

整形後のメモのみを出力してください。`;

      if (provider === "claude") {
        const claude = getClaudeClient();
        const message = await claude.messages.create({
          model: "claude-3-haiku-20240307",
          max_tokens: 2048,
          messages: [{ role: "user", content: prompt }],
        });

        arrangedText = message.content[0].type === "text" ? message.content[0].text : "";
        inputTokens = message.usage.input_tokens;
        outputTokens = message.usage.output_tokens;
        cost = (inputTokens * 0.00025 + outputTokens * 0.00125) / 1000;
      } else if (provider === "gemini") {
        const gemini = getGeminiClient();
        const model = gemini.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
        const result = await model.generateContent(prompt);

        arrangedText = result.response.text();
        inputTokens = Math.ceil(prompt.length / 4);
        outputTokens = Math.ceil(arrangedText.length / 4);
        cost = (inputTokens * 0.000075 + outputTokens * 0.0003) / 1000;
      } else if (provider === "openai") {
        const openai = getOpenAIClient();
        const completion = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
        });

        arrangedText = completion.choices[0].message.content || "";
        inputTokens = completion.usage?.prompt_tokens || 0;
        outputTokens = completion.usage?.completion_tokens || 0;
        cost = (inputTokens * 0.00015 + outputTokens * 0.0006) / 1000;
      }

      await recordUsage(userId, "arrangeMemo", provider, inputTokens, outputTokens, cost);

      return res.json({
        arrangedText,
        usage: {
          current: usage.current + 1,
          limit: usage.limit,
          remaining: usage.limit - usage.current - 1,
        },
      });
    } catch (error) {
      console.error("arrangeMemo error:", error);
      return res.status(500).json({
        error: "AI processing failed",
        details: error instanceof Error ? error.message : String(error),
      });
    }
  });

// ====================================
// エンドポイント3: カテゴリー要約
// ====================================
export const summarizeCategory = functions
  .region("asia-northeast1")
  .https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send("");
    }

    try {
      const { userId, memos, categoryName, provider = "gemini" } = req.body;

      if (!userId || !memos || !categoryName) {
        return res.status(400).json({
          error: "Missing required fields: userId, memos, categoryName",
        });
      }

      const usage = await checkUsageLimit(userId);
      if (!usage.allowed) {
        return res.status(429).json({
          error: "Monthly usage limit exceeded",
          current: usage.current,
          limit: usage.limit,
        });
      }

      const memosText = memos.map((m: any) => m.content).join("\n\n---\n\n");
      const prompt = `以下は「${categoryName}」カテゴリーのメモ一覧です。
これらのメモを分析し、以下の形式で要約を作成してください:

1. 全体の要約（2-3文）
2. 重要なポイント（3-5個の箇条書き）
3. トレンドや傾向があれば記載

メモ一覧:
${memosText}`;

      let summary = "";
      let inputTokens = 0;
      let outputTokens = 0;
      let cost = 0;

      if (provider === "claude") {
        const claude = getClaudeClient();
        const message = await claude.messages.create({
          model: "claude-3-haiku-20240307",
          max_tokens: 2048,
          messages: [{ role: "user", content: prompt }],
        });

        summary = message.content[0].type === "text" ? message.content[0].text : "";
        inputTokens = message.usage.input_tokens;
        outputTokens = message.usage.output_tokens;
        cost = (inputTokens * 0.00025 + outputTokens * 0.00125) / 1000;
      } else if (provider === "gemini") {
        const gemini = getGeminiClient();
        const model = gemini.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
        const result = await model.generateContent(prompt);

        summary = result.response.text();
        inputTokens = Math.ceil(prompt.length / 4);
        outputTokens = Math.ceil(summary.length / 4);
        cost = (inputTokens * 0.000075 + outputTokens * 0.0003) / 1000;
      } else if (provider === "openai") {
        const openai = getOpenAIClient();
        const completion = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
        });

        summary = completion.choices[0].message.content || "";
        inputTokens = completion.usage?.prompt_tokens || 0;
        outputTokens = completion.usage?.completion_tokens || 0;
        cost = (inputTokens * 0.00015 + outputTokens * 0.0006) / 1000;
      }

      await recordUsage(userId, "summarizeCategory", provider, inputTokens, outputTokens, cost);

      return res.json({
        summary,
        usage: {
          current: usage.current + 1,
          limit: usage.limit,
          remaining: usage.limit - usage.current - 1,
        },
      });
    } catch (error) {
      console.error("summarizeCategory error:", error);
      return res.status(500).json({
        error: "AI processing failed",
        details: error instanceof Error ? error.message : String(error),
      });
    }
  });

// ====================================
// エンドポイント4: 使用量取得
// ====================================
export const getUsage = functions
  .region("asia-northeast1")
  .https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send("");
    }

    try {
      const { userId } = req.body;

      if (!userId) {
        return res.status(400).json({ error: "Missing required field: userId" });
      }

      const usage = await checkUsageLimit(userId);

      return res.json({
        current: usage.current,
        limit: usage.limit,
        remaining: usage.limit - usage.current,
      });
    } catch (error) {
      console.error("getUsage error:", error);
      return res.status(500).json({
        error: "Failed to get usage",
        details: error instanceof Error ? error.message : String(error),
      });
    }
  });
```

---

### Step 6: Firestoreセキュリティルール設定

`firestore.rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 使用量データ: ユーザー自身のみ読み取り可能
    match /usage/{userId}/monthly/{month} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false; // Cloud Functionsからのみ書き込み
    }

    // 使用量ログ: 管理者のみアクセス
    match /usage_logs/{logId} {
      allow read, write: if false; // Cloud Functionsからのみ
    }
  }
}
```

---

### Step 7: 環境変数設定（APIキー）

```bash
# Claude APIキー設定
firebase functions:config:set ai.claude_key="sk-ant-api03-YOUR-KEY-HERE"

# Gemini APIキー設定
firebase functions:config:set ai.gemini_key="AIzaSyYOUR-KEY-HERE"

# OpenAI APIキー設定
firebase functions:config:set ai.openai_key="sk-YOUR-KEY-HERE"

# 設定確認
firebase functions:config:get

# ローカル開発用（.runtimeconfig.json 生成）
firebase functions:config:get > functions/.runtimeconfig.json
```

**⚠️ 重要**: `.runtimeconfig.json` は `.gitignore` に追加

---

### Step 8: デプロイ

```bash
# ビルド
cd functions
npm run build

# デプロイ（全て）
firebase deploy

# Functions のみデプロイ
firebase deploy --only functions

# 特定のFunctionのみデプロイ
firebase deploy --only functions:extractTags
```

デプロイ完了後、エンドポイントURLが表示されます:
```
✔  functions[asia-northeast1-extractTags]: https://asia-northeast1-quickmemo-ai.cloudfunctions.net/extractTags
✔  functions[asia-northeast1-arrangeMemo]: https://asia-northeast1-quickmemo-ai.cloudfunctions.net/arrangeMemo
✔  functions[asia-northeast1-summarizeCategory]: https://asia-northeast1-quickmemo-ai.cloudfunctions.net/summarizeCategory
✔  functions[asia-northeast1-getUsage]: https://asia-northeast1-quickmemo-ai.cloudfunctions.net/getUsage
```

---

### Step 9: 動作テスト

#### 9-1. curlでテスト

```bash
# タグ抽出テスト
curl -X POST \
  https://asia-northeast1-quickmemo-ai.cloudfunctions.net/extractTags \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-001",
    "content": "明日の会議で新プロジェクトの提案をする。資料作成が必要。",
    "provider": "gemini"
  }'

# 期待するレスポンス:
{
  "tags": ["会議", "プロジェクト", "提案", "資料作成"],
  "usage": {
    "current": 1,
    "limit": 100,
    "remaining": 99
  }
}
```

#### 9-2. Firebaseコンソールで確認

1. Firebase Console > Firestore Database
2. `usage` コレクション確認
3. `usage_logs` コレクション確認

---

## 🔧 トラブルシューティング

### エラー1: "Missing required fields"

**原因**: リクエストボディが正しくない

**解決**:
```bash
# Content-Type ヘッダーを確認
-H "Content-Type: application/json"
```

### エラー2: "API key not configured"

**原因**: 環境変数が設定されていない

**解決**:
```bash
firebase functions:config:set ai.gemini_key="YOUR-KEY"
firebase deploy --only functions
```

### エラー3: "CORS error"

**原因**: CORS設定が不足

**解決**: コードにCORS対応が含まれているか確認

---

## 📊 監視・ログ

### Cloud Functionsログ確認

```bash
# リアルタイムログ
firebase functions:log

# 特定のFunction
firebase functions:log --only extractTags

# エラーのみ
firebase functions:log --only extractTags | grep ERROR
```

### Firebase Consoleでログ確認

1. Firebase Console > Functions
2. 各Functionをクリック
3. 「ログ」タブ

---

## 💰 コスト監視

### 使用量確認

1. Firebase Console > 使用量と請求額
2. Cloud Functions の実行回数確認
3. Firestore の読み取り/書き込み回数確認

### アラート設定

1. Google Cloud Console > 課金 > 予算とアラート
2. 予算設定（例: $10/月）
3. アラート閾値設定（50%, 90%, 100%）

---

## 🚀 次のステップ

✅ **Firebase側完了！**

次は iOS アプリ側の実装:
1. ProAIService.swift 作成
2. AIManager拡張
3. UI更新

---

最終更新: 2025-01-25
