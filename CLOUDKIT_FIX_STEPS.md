# CloudKit「Use default container」が選択できない問題の解決手順

## 現在の状況
- CloudKit Capabilityは追加されている
- entitlementsファイルにCloudKit設定は存在
- しかし「Use default container」が選択できない

## 解決手順

### 手順1: entitlementsファイルの修正完了
✅ 以下の設定を追加済み：
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.yokAppDev.quickMemoApp</string>
</array>
```

### 手順2: Xcodeでの操作

1. **プロジェクトをクリーン**
   - `Product → Clean Build Folder` (Shift+Cmd+K)

2. **DerivedDataを削除**（オプション）
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/quickMemoApp-*
   ```

3. **Xcodeを完全に再起動**
   - Xcodeを終了
   - 再度Xcodeを起動
   - quickMemoApp.xcodeprojを開く

4. **CloudKit Capabilityをリセット**
   - Signing & Capabilities タブ
   - CloudKitセクションの「×」ボタンで削除
   - 「+ Capability」でCloudKitを再追加

### 手順3: 代替方法（手動設定）

もし「Use default container」がまだ表示されない場合：

1. **カスタムコンテナとして追加**
   - CloudKit セクション内で
   - 「+ Containers」をクリック（もしボタンがある場合）
   - または「Specify custom containers」を選択
   - `iCloud.yokAppDev.quickMemoApp`を入力

2. **プロジェクト設定から直接編集**
   - プロジェクトナビゲータ → quickMemoApp.xcodeproj
   - Build Settings タブ
   - 「All」と「Combined」を選択
   - 検索バーに「entitlement」と入力
   - CODE_SIGN_ENTITLEMENTS = quickMemoApp/quickMemoApp.entitlements を確認

### 手順4: Apple Developer Portalで確認

1. https://developer.apple.com/account にアクセス
2. Certificates, Identifiers & Profiles → Identifiers
3. `yokAppDev.quickMemoApp`を選択
4. Capabilities：
   - ☑️ iCloud（CloudKitを含む）が有効か確認
   - Configure → CloudKit Containersで`iCloud.yokAppDev.quickMemoApp`を選択または作成

### 手順5: プロビジョニングプロファイルの更新

1. Xcode → Settings → Accounts
2. Apple IDを選択
3. 「Download Manual Profiles」をクリック
4. または Automatically manage signing をオフ→オンに切り替え

### 手順6: 動作確認

1. **ビルドテスト**
   ```bash
   xcodebuild -project quickMemoApp.xcodeproj \
              -scheme quickMemoApp \
              -destination 'platform=iOS Simulator,OS=18.5,name=iPhone 16' \
              clean build
   ```

2. **実機/シミュレータでテスト**
   - アプリを起動
   - コンソールで確認：
   ```
   CloudKit Container ID: iCloud.yokAppDev.quickMemoApp
   ```

### それでも解決しない場合

#### オプションA: 新しいコンテナIDを使用
```swift
// CloudKitManager.swift を編集
self.container = CKContainer(identifier: "iCloud.com.yokAppDev.quickMemoApp")
```

#### オプションB: プロジェクト設定をリセット
1. quickMemoApp.xcodeprojを右クリック
2. 「Show Package Contents」
3. project.pbxprojをテキストエディタで開く
4. CloudKit関連の設定を探して確認

### チェックリスト

- [ ] entitlementsファイルにコンテナIDが記載されている
- [ ] Xcodeを再起動した
- [ ] CloudKit Capabilityを削除→再追加した
- [ ] Apple Developer PortalでCloudKitが有効
- [ ] プロビジョニングプロファイルが最新
- [ ] ビルドエラーがない
- [ ] コンソールにコンテナIDが表示される

## 最終手段

完全にリセットする場合：
1. CloudKit Capabilityを削除
2. quickMemoApp.entitlementsファイルを削除
3. Xcodeを再起動
4. CloudKit Capabilityを新規追加（entitlementsファイルが自動生成される）
5. 自動生成されたファイルにコンテナIDが含まれているか確認