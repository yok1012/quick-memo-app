# Xcode Capabilities Setup for Sign in with Apple & CloudKit

このドキュメントは、Sign in with AppleとCloudKitをXcodeで有効化するための手順を説明します。

## 1. Sign in with Appleの有効化

### Xcodeでの設定手順：
1. Xcodeでプロジェクトを開く
2. quickMemoApp targetを選択
3. "Signing & Capabilities" タブを選択
4. "+" ボタンをクリックして "Sign in with Apple" を追加

### entitlements.plistに自動的に追加される内容：
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

## 2. CloudKitの有効化

### Xcodeでの設定手順：
1. quickMemoApp targetの "Signing & Capabilities" タブで
2. "+" ボタンをクリックして "CloudKit" を追加
3. CloudKit dashboardで以下を設定：
   - Container: 新規作成または既存の選択
   - Container ID: `iCloud.yokAppDev.quickMemoApp` (推奨)

### entitlements.plistに自動的に追加される内容：
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.yokAppDev.quickMemoApp</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

## 3. CloudKit Schemaの設定

### CloudKit Dashboardでの設定：
1. https://icloud.developer.apple.com/dashboard にアクセス
2. アプリを選択
3. CloudKit Databaseを選択
4. Development環境で以下のRecord Typeを作成：

#### Record Type: SubscriptionStatus
- Fields:
  - `userIdentifier` (String, Required)
  - `transactionID` (String, Required)
  - `productID` (String, Required)
  - `isPro` (Int64/Bool, Required)
  - `lastUpdated` (Date/Time, Required)
  - `deviceID` (String, Optional)

5. Production環境にデプロイ

## 4. App Store Connect設定

### Sign in with Appleの設定：
1. App Store Connectにログイン
2. アプリを選択
3. "App Information" → "Sign in with Apple"
4. 必要に応じてプライバシーポリシーURLを設定

## 5. プライバシーポリシーの追記事項

以下の内容をプライバシーポリシーに追加：

```
### Sign in with Appleについて
当アプリでは、Sign in with Appleを使用した任意のアカウント登録機能を提供しています。
- 登録は任意であり、アプリの基本機能は登録なしでも利用可能です
- Sign in with Appleで提供される情報（ユーザーID、メールアドレス、名前）は、サブスクリプション権利の管理のみに使用されます
- 収集した情報は第三者と共有されません

### iCloudデータ同期について
- Pro版の購入情報は、同一Apple IDでサインインしているデバイス間で自動的に同期されます
- 同期データはAppleのiCloudサービスに安全に保存されます
```

## 6. テストアカウント

### Sandbox環境でのテスト：
1. Xcode → Settings → Accounts
2. Sandbox Testerアカウントを追加
3. デバイスの設定 → App Store → Sandbox Accountでログイン

## 注意事項

- CloudKitコンテナIDは一度作成すると変更できません
- Production環境へのデプロイ前に、Development環境で十分にテストしてください
- Sign in with Appleは実機でのみテスト可能です（シミュレータでは制限があります）

## トラブルシューティング

### CloudKitエラー: "Container not found"
- Xcodeでプロビジョニングプロファイルを再生成
- CloudKit Capabilityを削除して再追加

### Sign in with Appleエラー: "Invalid client"
- Bundle IDが正しいか確認
- App Store ConnectでSign in with Appleが有効になっているか確認

## 審査時の注意点

App Store審査時には以下を明記：
- Sign in with Appleは任意機能であること
- 登録しなくてもアプリは使用可能であること
- 他デバイスでの利用には、同一Apple IDでの「購入の復元」も可能であること