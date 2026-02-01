# QuickMemo - 瞬間メモ & タスク管理

[![App Store](https://img.shields.io/badge/App%20Store-Download-blue)](https://apps.apple.com/)
[![Version](https://img.shields.io/badge/version-3.0-green)]()
[![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20watchOS%2011.5%2B-lightgrey)]()

振って開く、素早くメモ。カテゴリー＆タグで整理、AI機能搭載の高速メモアプリ。

---

## 📱 概要

**QuickMemo**は、思いついた瞬間にメモを取ることができる、高速メモアプリです。

デバイスを振るだけでメモ入力画面が開き、大切なアイデアや情報を逃しません。仕事、プライベート、アイデアなど、カテゴリー別に整理でき、スマートなタグ機能で後から簡単に見つけることができます。

### 主な機能

- 📝 **シェイクジェスチャー**: デバイスを振るだけで即座にメモ開始
- 🤖 **AI機能**: タグ抽出、メモアレンジ、カテゴリー要約
- 📁 **カテゴリー管理**: カスタマイズ可能な分類とアイコン
- 🏷️ **スマートタグ**: 内容から自動でタグを提案
- 📅 **カレンダー連携**: メモを自動でカレンダーに記録
- ⌚ **Apple Watch対応**: Watch上で直接メモ入力、オフラインでも使用可能
- ☁️ **iCloud同期**: Pro版で全デバイス共有（実装中）
- 🔄 **データ管理**: インポート/エクスポート機能

---

## 📚 ドキュメント

### ユーザー向け

- 📖 **[日本語マニュアル](USER_MANUAL_ja.md)** - アプリの使い方、AI機能、Pro版の詳細
- 📖 **[English Manual](USER_MANUAL_en.md)** - How to use, AI features, Pro version details
- 📖 **[中文手册](USER_MANUAL_zh-Hans.md)** - 使用方法、AI功能、Pro版本详情

### 開発者向け

- 🛠️ **[CLAUDE.md](CLAUDE.md)** - Claude Code用の開発ガイド
- 📋 **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - テストガイド
- 🖼️ **[SCREENSHOT_GUIDE.md](SCREENSHOT_GUIDE.md)** - スクリーンショット作成ガイド

---

## ✨ 機能一覧

### 基本機能（無料版）

- ✅ メモ作成・編集・削除（最大100件）
- ✅ カテゴリー管理（最大5つ）
- ✅ タグ管理（15個/メモ）
- ✅ シェイクジェスチャー
- ✅ カレンダー連携
- ✅ Apple Watch対応
- ✅ 検索機能
- ✅ データエクスポート（CSV, JSON）
- ✅ データインポート（TXT, MD, CSV, JSON）
- ✅ 多言語対応（日本語、英語、簡体字中国語）

### AI機能（要APIキー設定）

- 🤖 **タグ抽出**: Gemini AIがメモから関連タグを自動提案
- 🤖 **メモアレンジ**: Claude AIがメモを様々な形式に整形
  - 要約、ビジネス形式、カジュアル化、詳細化、箇条書き、翻訳
  - カスタムプロンプト対応
- 🤖 **カテゴリー要約**: Claude AIがカテゴリー内の全メモを分析
- 📊 **AI使用統計**: リクエスト数、トークン数、推定コスト表示

### Pro版限定機能

- 🚀 **無制限のメモ**: 100件制限なし
- 🚀 **無制限のカテゴリー**: 5つ制限なし
- 🚀 **無制限のタグ**: 15個/メモ制限なし
- ☁️ **iCloud同期**: 全デバイスで自動同期（実装中）
- 💾 **iCloudバックアップ**: 手動バックアップ・復元
- 🔔 **定期リマインダー**: メモの見逃しを防ぐ通知
- 🎨 **ウィジェットカスタマイズ**: 表示カテゴリーを自由に選択

**価格:**
- 月額プラン: ¥200/月
- 買い切りライセンス: ¥500（永久利用）

---

## 🚀 はじめに

### インストール

App Storeからダウンロード：

[![Download on App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/)

### 基本的な使い方

1. **メモを作成**: iPhoneを振る、または「+」ボタンをタップ
2. **カテゴリーで整理**: メモを仕事、プライベートなどに分類
3. **タグで詳細分類**: 複数のタグで柔軟に管理
4. **カレンダーに記録**: 所要時間を設定して自動同期

詳細な使い方は[ユーザーマニュアル](USER_MANUAL_ja.md)をご覧ください。

### AI機能の設定

1. 設定 > AI機能
2. 使用したいAIプロバイダーのAPIキーを入力
   - **Gemini**: [Google AI Studio](https://makersuite.google.com/app/apikey)
   - **Claude**: [Anthropic Console](https://console.anthropic.com/)
   - **ChatGPT**: [OpenAI Platform](https://platform.openai.com/)
3. 各機能で対応するAIを使用

詳細は[AI機能ガイド](USER_MANUAL_ja.md#ai機能)をご覧ください。

---

## 📱 対応環境

- **iOS**: 16.0以上
- **watchOS**: 11.5以上
- **言語**: 日本語、英語、簡体字中国語
- **AI対応**: Gemini, Claude, ChatGPT

---

## 🔒 プライバシーとセキュリティ

- メモデータはデバイス内に安全に保存
- AI APIキーはKeychainに暗号化して保存
- AIプロバイダーへのデータ送信は、ユーザーが機能を使用した時のみ
- iCloud同期はPro版のみ（オプトイン）

詳細は[プライバシーポリシー](https://yok1012.github.io/quickMemoPrivacypolicy/)をご覧ください。

---

## 🛠️ 技術スタック

### アーキテクチャ

- **フレームワーク**: SwiftUI
- **最小デプロイメントターゲット**: iOS 16.0, watchOS 11.5
- **ストレージ**: UserDefaults (App Group), CloudKit (Pro版)
- **課金**: StoreKit 2
- **AI統合**:
  - Gemini API (Google AI Studio)
  - Claude API (Anthropic)
  - ChatGPT API (OpenAI)

### プロジェクト構造

```
quickMemoApp/
├── quickMemoApp/              # メインiOSアプリ
│   ├── Models/                # データモデル
│   ├── Views/                 # SwiftUIビュー
│   ├── Services/              # ビジネスロジック
│   ├── Utils/                 # ユーティリティ
│   └── Resources/             # ローカライズファイル
├── quickMemoWatch Watch App/  # watchOSアプリ
├── quickMemoWidget/           # ウィジェット拡張
└── quickMemoAppTests/         # テスト
```

---

## 📝 開発

### ビルド手順

```bash
# クリーンビルド
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean -project quickMemoApp.xcodeproj -scheme quickMemoApp

# Releaseビルド（シミュレーター）
xcodebuild -project quickMemoApp.xcodeproj \
  -scheme quickMemoApp \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

詳細は[CLAUDE.md](CLAUDE.md)をご覧ください。

### テスト

```bash
# ユニットテスト実行
xcodebuild test \
  -project quickMemoApp.xcodeproj \
  -scheme quickMemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## 🐛 既知の問題

現在報告されている問題はありません。

バグ報告や機能要望は、Issueを作成してください。

---

## 📄 ライセンス

このアプリは以下の条件で配布されています：

- 利用規約: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- プライバシーポリシー: https://yok1012.github.io/quickMemoPrivacypolicy/

---

## 📞 サポート

### お問い合わせ

- **メール**: quickmemo.support@example.com
- **プライバシーポリシー**: https://yok1012.github.io/quickMemoPrivacypolicy/

### よくある質問

詳細は[FAQ](USER_MANUAL_ja.md#よくある質問)をご覧ください。

---

## 🎯 ロードマップ

### バージョン 3.0（現在）
- ✅ AI機能統合（タグ抽出、メモアレンジ、カテゴリー要約）
- ✅ AI使用統計
- ✅ データインポート/エクスポート
- ✅ 多言語対応（日本語、英語、中国語）
- ✅ ウィジェット対応

### 今後の予定
- 🔄 iCloud自動同期の完全実装
- 📱 iPad最適化
- 🎨 テーマカスタマイズ
- 📊 メモ統計・分析機能
- 🔐 パスコードロック

---

## 👥 貢献

このプロジェクトへの貢献を歓迎します。

プルリクエストを送る前に：
1. 既存のIssueを確認
2. 新しい機能の場合は、まずIssueで提案
3. コーディング規約に従う（[CLAUDE.md](CLAUDE.md)参照）

---

## 🙏 謝辞

このアプリは以下のテクノロジーを使用しています：

- **AI**: Gemini (Google), Claude (Anthropic), ChatGPT (OpenAI)
- **開発支援**: Claude Code by Anthropic
- **フレームワーク**: SwiftUI, StoreKit, EventKit, WatchConnectivity

---

**QuickMemo** - 思いついた瞬間を逃さない、あなたのメモパートナー

© 2024-2025 QuickMemo. All rights reserved.

---

**バージョン履歴**

- **3.0** (2025-01) - AI機能統合、多言語対応、データ管理機能強化
- **2.0** (2024-12) - Pro版機能追加、定期リマインダー
- **1.0** (2024-11) - 初回リリース
