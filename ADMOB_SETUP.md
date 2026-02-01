# AdMob 広告機能セットアップガイド

このガイドでは、quickMemoAppに報酬型広告機能を有効にするための設定手順を説明します。

## 1. AdMob SDK の追加（Swift Package Manager）

1. Xcodeでプロジェクトを開く
2. `File` > `Add Package Dependencies...` を選択
3. 検索ボックスに以下のURLを入力:
   ```
   https://github.com/googleads/swift-package-manager-google-mobile-ads
   ```
4. バージョンを選択（最新の安定版を推奨）
5. `Add Package` をクリック
6. `GoogleMobileAds` を選択してターゲットに追加

## 2. Info.plist の設定

このプロジェクトは「Generate Info.plist」が有効なため、Info.plistはXcodeのビルド設定で管理されています。

### 方法A: Xcodeのプロジェクト設定から追加

1. Xcodeでプロジェクトを選択
2. `quickMemoApp` ターゲットを選択
3. `Info` タブを選択
4. 以下のキーを追加:

| Key | Type | Value |
|-----|------|-------|
| `GADApplicationIdentifier` | String | `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` |
| `NSUserTrackingUsageDescription` | String | パーソナライズされた広告を表示するために、トラッキングの許可をお願いしています。 |
| `SKAdNetworkItems` | Array | (下記参照) |

### 方法B: Info.plist ファイルを直接編集

プロジェクトルートに `Info.plist` ファイルを作成し、以下の内容を追加:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- AdMob App ID -->
    <key>GADApplicationIdentifier</key>
    <string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>

    <!-- App Tracking Transparency (ATT) 許可メッセージ -->
    <key>NSUserTrackingUsageDescription</key>
    <string>パーソナライズされた広告を表示するために、トラッキングの許可をお願いしています。</string>

    <!-- SKAdNetwork IDs (Google提供) -->
    <key>SKAdNetworkItems</key>
    <array>
        <dict>
            <key>SKAdNetworkIdentifier</key>
            <string>cstr6suwn9.skadnetwork</string>
        </dict>
        <!-- 他のSKAdNetwork IDsはGoogleのドキュメントを参照 -->
    </array>
</dict>
</plist>
```

## 3. AdMob ダッシュボードでの設定

### 3.1 アプリの登録

1. [AdMob コンソール](https://admob.google.com/) にログイン
2. `アプリ` > `アプリを追加` を選択
3. プラットフォーム: `iOS` を選択
4. App Storeに公開済みの場合は検索、未公開の場合は手動で追加
5. アプリ名とBundle IDを入力

### 3.2 広告ユニットの作成

1. アプリ設定画面で `広告ユニット` を選択
2. `広告ユニットを追加` をクリック
3. `リワード広告` を選択
4. 広告ユニット名を入力（例: `QuickMemo Reward Ad`）
5. 報酬の設定:
   - 報酬タイプ: `memo_slot`（任意の名前）
   - 報酬の数量: `10`
6. 作成された広告ユニットIDをコピー

### 3.3 コードの更新

`AdMobManager.swift` の本番用広告IDを更新:

```swift
private var rewardedAdUnitID: String {
    #if DEBUG
    // テスト用広告ID（そのまま）
    return "ca-app-pub-3940256099942544/1712485313"
    #else
    // 本番用広告ID（AdMobダッシュボードで取得したIDに置き換え）
    return "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
    #endif
}
```

## 4. App Tracking Transparency (ATT) の実装

iOS 14.5以降では、ユーザーのトラッキング許可が必要です。

`RewardAdView.swift` の `onAppear` で既に以下が実装されています:

```swift
.onAppear {
    // ATTの状態を確認
    adManager.checkTrackingAuthorizationStatus()
    // ...
}
```

ATT許可ダイアログは、アプリの適切なタイミング（例: 設定画面や初回起動時）で表示することを推奨します。

## 5. テスト方法

### デバッグビルドでのテスト

デバッグビルドでは自動的にGoogleのテスト広告が表示されます。

### シミュレータでのテスト

シミュレータではテスト広告が表示されます。実機テストを推奨します。

### 実機でのテスト

1. テストデバイスとして登録:
   - AdMobダッシュボード > 設定 > テストデバイス で追加
   - または、コンソールログからデバイスIDを取得して `GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers` に追加

## 6. 多言語対応

ATT許可メッセージは `Info.plist` の多言語化で対応します:

1. `InfoPlist.strings` ファイルを各言語用に作成
2. 以下の内容を追加:

**Japanese (ja.lproj/InfoPlist.strings):**
```
"NSUserTrackingUsageDescription" = "パーソナライズされた広告を表示するために、トラッキングの許可をお願いしています。";
```

**English (en.lproj/InfoPlist.strings):**
```
"NSUserTrackingUsageDescription" = "We use tracking to show you personalized ads.";
```

**Chinese Simplified (zh-Hans.lproj/InfoPlist.strings):**
```
"NSUserTrackingUsageDescription" = "我们使用跟踪功能为您展示个性化广告。";
```

## 7. SKAdNetwork の設定

GoogleのSKAdNetwork IDsリストは以下から取得できます:
https://developers.google.com/admob/ios/ios14#skadnetwork

最新のリストを `Info.plist` の `SKAdNetworkItems` に追加してください。

## 8. 注意事項

- **本番リリース前**: 必ずテスト広告IDを本番広告IDに置き換えてください
- **App Store審査**: ATT許可メッセージが適切に設定されていることを確認
- **収益化**: 広告収入はAdMobダッシュボードで確認できます
- **プライバシーポリシー**: 広告表示についてプライバシーポリシーに記載が必要です

## 実装済みファイル

- `quickMemoApp/Services/AdMobManager.swift` - AdMob SDK のラッパー
- `quickMemoApp/Services/RewardManager.swift` - 報酬メモ枠の管理
- `quickMemoApp/Views/RewardAdView.swift` - 広告視聴UI
- `quickMemoApp/Resources/Localizable.strings` - 日本語翻訳
- `quickMemoApp/Resources/en.lproj/Localizable.strings` - 英語翻訳
- `quickMemoApp/Resources/zh-Hans.lproj/Localizable.strings` - 中国語（簡体字）翻訳
