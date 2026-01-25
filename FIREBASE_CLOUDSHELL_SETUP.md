# Firebase Cloud Shell セットアップ手順

Google Cloud Console の Cloud Shell でFirebase Functionsを設定・デプロイする完全ガイド

---

## 🚀 前提条件

- Googleアカウント
- クレジットカード（Blaze プラン用、無料枠内なら課金されない）

---

## ステップ1: Firebase プロジェクト作成

### 1-1. Firebase Console でプロジェクト作成

1. **Firebase Console を開く**
   ```
   https://console.firebase.google.com/
   ```

2. **「プロジェクトを追加」をクリック**

3. **プロジェクト設定**
   - プロジェクト名: `quickmemo-ai`（または任意の名前）
   - Google Analytics: 有効化（推奨）
   - 地域: 「日本」を選択

4. **「プロジェクトを作成」をクリック**

### 1-2. Blaze プランにアップグレード

**重要**: Cloud Functions を使用するには必須

1. Firebase Console > 左下の歯車アイコン > **「使用量と請求額」**
2. **「詳細と設定」** > **「プランを変更」**
3. **「Blazeプランにアップグレード」**
4. クレジットカード情報を入力

**無料枠（毎月）**:
- Cloud Functions: 200万回実行
- Firestore: 5万回読み取り、2万回書き込み
- Cloud Storage: 5GB

→ **初期は無料枠内で運用可能**

### 1-3. プロジェクトIDを確認

Firebase Console > プロジェクト設定 > **「プロジェクトID」** をメモ

例: `quickmemo-ai` または `quickmemo-ai-abc123`

---

## ステップ2: Cloud Shell を開く

### 2-1. Google Cloud Console にアクセス

```
https://console.cloud.google.com/
```

### 2-2. プロジェクトを選択

画面上部のプロジェクト選択 > 先ほど作成した **`quickmemo-ai`** を選択

### 2-3. Cloud Shell を起動

画面右上の **「Cloud Shell をアクティブにする」** アイコンをクリック
（ターミナルアイコン: `>_`）

Cloud Shell が画面下部に表示されます。

---

## ステップ3: Firebase CLI セットアップ

### 3-1. Node.js バージョン確認

```bash
node --version
# v20.x.x 以上であることを確認
```

もし古い場合:
```bash
# Node.js 20 をインストール
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
```

### 3-2. Firebase CLI インストール

```bash
# Firebase CLI をグローバルインストール
npm install -g firebase-tools

# バージョン確認
firebase --version
```

### 3-3. Firebase ログイン

Cloud Shell では認証が少し特殊です：

```bash
# Firebase ログイン（Cloud Shell用）
firebase login --no-localhost

# 表示されたURLをコピーしてブラウザで開く
# Googleアカウントでログイン
# 表示された認証コードをCloud Shellに貼り付け
```

ログイン成功確認：
```bash
firebase projects:list

# 先ほど作成した quickmemo-ai が表示されればOK
```

---

## ステップ4: プロジェクト初期化

### 4-1. 作業ディレクトリ作成

```bash
# ホームディレクトリに移動
cd ~

# プロジェクトディレクトリ作成
mkdir quickmemo-firebase
cd quickmemo-firebase
```

### 4-2. Firebase プロジェクト初期化

```bash
firebase init

# 以下のように選択:
```

**質問1: Which Firebase features do you want to set up?**
```
◉ Functions: Configure and deploy Cloud Functions
◉ Firestore: Deploy rules and create indexes for Firestore

# スペースキーで選択、Enterで確定
```

**質問2: Please select an option:**
```
→ Use an existing project
```

**質問3: Select a default Firebase project:**
```
→ quickmemo-ai (または作成したプロジェクト名)
```

**質問4: What language would you like to use to write Cloud Functions?**
```
→ TypeScript
```

**質問5: Do you want to use ESLint to catch probable bugs?**
```
→ Yes
```

**質問6: Do you want to install dependencies with npm now?**
```
→ Yes
```

**質問7-8: Firestore Rules/Indexes**
```
→ (デフォルトのまま Enter)
```

初期化完了！

---

## ステップ5: AI SDK インストール

### 5-1. functions ディレクトリに移動

```bash
cd functions
```

### 5-2. AI SDK をインストール

```bash
# AI SDKをインストール
npm install @anthropic-ai/sdk @google/generative-ai openai

# 型定義
npm install --save-dev @types/node

# インストール確認
npm list @anthropic-ai/sdk @google/generative-ai openai
```

---

## ステップ6: Cloud Functions コード作成

### 6-1. コードエディタを開く

Cloud Shell の上部メニュー > **「エディタを開く」** をクリック

または、コマンドで開く：
```bash
cloudshell edit functions/src/index.ts
```

### 6-2. index.ts の内容を置き換え

**重要**: 以下のコードを `functions/src/index.ts` に完全に置き換えてください

```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Anthropic from "@anthropic-ai/sdk";
import { GoogleGenerativeAI } from "@google/generative-ai";
import OpenAI from "openai";

// Firebase Admin初期化
admin.initializeApp();
const db = admin.firestore();

// AI クライアント初期化
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

// 使用量チェック
async function checkUsageLimit(userId: string): Promise<{ allowed: boolean; current: number; limit: number }> {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  const usageDoc = await db
    .collection("usage")
    .doc(userId)
    .collection("monthly")
    .doc(currentMonth)
    .get();

  const monthlyLimit = 100;
  const currentUsage = usageDoc.exists ? (usageDoc.data()?.count || 0) : 0;

  return {
    allowed: currentUsage < monthlyLimit,
    current: currentUsage,
    limit: monthlyLimit,
  };
}

// 使用量記録
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

// タグ抽出
export const extractTags = functions
  .region("asia-northeast1")
  .https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      return res.status(204).send("");
    }

    try {
      const { userId, content, provider = "gemini" } = req.body;

      if (!userId || !content) {
        return res.status(400).json({ error: "Missing required fields: userId, content" });
      }

      const usage = await checkUsageLimit(userId);
      if (!usage.allowed) {
        return res.status(429).json({
          error: "Monthly usage limit exceeded",
          current: usage.current,
          limit: usage.limit,
        });
      }

      let tags: string[] = [];
      let inputTokens = 0;
      let outputTokens = 0;
      let cost = 0;

      if (provider === "gemini") {
        const gemini = getGeminiClient();
        const model = gemini.getGenerativeModel({
          model: "gemini-2.0-flash-exp",
          generationConfig: { responseMimeType: "application/json" },
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

        inputTokens = Math.ceil(content.length / 4);
        outputTokens = Math.ceil(responseText.length / 4);
        cost = (inputTokens * 0.000075 + outputTokens * 0.0003) / 1000;
      }

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

// 使用量取得
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

**保存**: Ctrl+S（Windows/Linux）または Cmd+S（Mac）

---

## ステップ7: Firestore セキュリティルール設定

### 7-1. firestore.rules を編集

```bash
cd ~/quickmemo-firebase
cloudshell edit firestore.rules
```

以下の内容に置き換え：

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 使用量データ
    match /usage/{userId}/monthly/{month} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false;
    }

    // 使用量ログ
    match /usage_logs/{logId} {
      allow read, write: if false;
    }
  }
}
```

保存: Ctrl+S

---

## ステップ8: 環境変数設定（APIキー）

### 8-1. Gemini APIキー取得（推奨・無料）

1. https://makersuite.google.com/app/apikey にアクセス
2. 「Create API key」をクリック
3. APIキーをコピー（例: `AIzaSyXXXXXXXXXXXXXXXX`）

### 8-2. APIキーを環境変数に設定

```bash
# Gemini APIキー設定
firebase functions:config:set ai.gemini_key="AIzaSyXXXXXXXXXXXXXXXX"

# 設定確認
firebase functions:config:get

# 出力例:
# {
#   "ai": {
#     "gemini_key": "AIzaSyXXXXXXXXXXXXXXXX"
#   }
# }
```

**（オプション）Claude / OpenAI も使う場合**:

```bash
# Claude APIキー設定
firebase functions:config:set ai.claude_key="sk-ant-api03-XXXXXXXX"

# OpenAI APIキー設定
firebase functions:config:set ai.openai_key="sk-XXXXXXXX"
```

---

## ステップ9: ビルド & デプロイ

### 9-1. ビルド

```bash
cd ~/quickmemo-firebase/functions
npm run build

# エラーがないことを確認
# "Successfully compiled X files with TypeScript"
```

### 9-2. デプロイ

```bash
cd ~/quickmemo-firebase

# Functions と Firestoreをデプロイ
firebase deploy

# デプロイ完了まで 2-3分待つ
```

**デプロイ成功例**:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/quickmemo-ai/overview

Functions deployed:
- extractTags(asia-northeast1)
  https://asia-northeast1-quickmemo-ai.cloudfunctions.net/extractTags
- getUsage(asia-northeast1)
  https://asia-northeast1-quickmemo-ai.cloudfunctions.net/getUsage
```

**重要**: このURLをメモしてください（後でiOSアプリから使用）

---

## ステップ10: 動作テスト

### 10-1. curlでテスト

Cloud Shell で以下を実行：

```bash
# タグ抽出テスト
curl -X POST \
  https://asia-northeast1-YOUR-PROJECT-ID.cloudfunctions.net/extractTags \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-001",
    "content": "明日の会議で新プロジェクトの提案をする。資料作成が必要。",
    "provider": "gemini"
  }'
```

**期待するレスポンス**:
```json
{
  "tags": ["会議", "プロジェクト", "提案", "資料作成"],
  "usage": {
    "current": 1,
    "limit": 100,
    "remaining": 99
  }
}
```

### 10-2. 使用量確認テスト

```bash
curl -X POST \
  https://asia-northeast1-YOUR-PROJECT-ID.cloudfunctions.net/getUsage \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-001"
  }'
```

**期待するレスポンス**:
```json
{
  "current": 1,
  "limit": 100,
  "remaining": 99
}
```

---

## ステップ11: Firestore でデータ確認

### 11-1. Firebase Console を開く

```
https://console.firebase.google.com/project/quickmemo-ai/firestore
```

### 11-2. データ確認

以下のコレクションが作成されているはず：

```
usage/
  └── test-user-001/
      └── monthly/
          └── 2025-01/
              count: 1
              lastUsed: (timestamp)

usage_logs/
  └── (auto-generated-id)/
      userId: "test-user-001"
      functionName: "extractTags"
      provider: "gemini"
      inputTokens: 30
      outputTokens: 20
      cost: 0.00000825
      timestamp: (timestamp)
```

---

## 🎯 完了チェックリスト

### Firebase側セットアップ完了 ✅

- [ ] Firebase プロジェクト作成
- [ ] Blaze プランにアップグレード
- [ ] Cloud Shell で Firebase CLI インストール
- [ ] プロジェクト初期化
- [ ] AI SDK インストール
- [ ] Cloud Functions コード作成
- [ ] Firestore ルール設定
- [ ] Gemini APIキー設定
- [ ] デプロイ成功
- [ ] curlテスト成功
- [ ] Firestoreデータ確認

---

## 📊 エンドポイント一覧（メモ）

デプロイ後に表示されたURLをメモ：

```
extractTags:
https://asia-northeast1-YOUR-PROJECT-ID.cloudfunctions.net/extractTags

getUsage:
https://asia-northeast1-YOUR-PROJECT-ID.cloudfunctions.net/getUsage
```

**次のステップ**: iOS アプリでこのURLを使用

---

## 🔧 トラブルシューティング

### エラー1: "Firebase CLI is not installed"

```bash
npm install -g firebase-tools
```

### エラー2: "Error: HTTP Error: 403, forbidden"

Blaze プランにアップグレードされているか確認

### エラー3: "API key not configured"

```bash
firebase functions:config:get
# ai.gemini_key が設定されているか確認

# 設定し直す
firebase functions:config:set ai.gemini_key="YOUR-KEY"
firebase deploy --only functions
```

### エラー4: デプロイタイムアウト

```bash
# タイムアウト時間を延長
firebase deploy --only functions --force
```

---

## 💰 コスト確認

### 使用量確認

```bash
# Cloud Functions実行回数確認
firebase functions:log

# または Firebase Console > Functions
```

### 予算アラート設定

1. Google Cloud Console > 課金 > 予算とアラート
2. 予算設定: $10/月
3. アラート: 50%, 90%, 100%

---

## 🚀 次のステップ

✅ **Firebase側完了！**

次は iOS アプリ側の実装:

1. ProAIService.swift 作成
   - エンドポイントURL設定
   - HTTP通信実装

2. AIManager拡張
   - Pro版判定
   - ProAIService呼び出し

3. UI更新
   - 使用量表示
   - Pro版バッジ

---

最終更新: 2025-01-25
