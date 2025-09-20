# Widget Extension設定手順

## 1. App Groups設定

### メインアプリ (quickMemoApp)
1. Xcodeでプロジェクトを開く
2. quickMemoAppターゲットを選択
3. **Signing & Capabilities**タブを開く
4. **+ Capability**をクリック
5. **App Groups**を追加
6. **+**ボタンをクリックして`group.yokAppDev.quickMemoApp`を追加
7. チェックボックスをオンにする

### Widget Extension (quickMemoWidgetExtension)
1. quickMemoWidgetExtensionターゲットを選択
2. **Signing & Capabilities**タブを開く
3. **+ Capability**をクリック
4. **App Groups**を追加
5. `group.yokAppDev.quickMemoApp`のチェックボックスをオンにする

## 2. URL Scheme設定

### メインアプリのみ設定
1. quickMemoAppターゲットを選択
2. **Info**タブを開く
3. **URL Types**セクションを展開（なければ追加）
4. **+**ボタンをクリック
5. 以下を設定：
   - **Identifier**: quickmemo
   - **URL Schemes**: quickmemo
   - **Role**: Editor

## 3. ビルド設定の確認

### Widget Extensionのデプロイメントターゲット
1. quickMemoWidgetExtensionターゲットを選択
2. **Build Settings**タブを開く
3. **iOS Deployment Target**を`16.0`に設定（メインアプリと合わせる）

## 4. ファイル共有設定

### DataModels.swiftをWidget Extensionに追加
1. Project Navigatorで`quickMemoApp/Models/DataModels.swift`を選択
2. File Inspectorを開く（右サイドバー）
3. **Target Membership**で`quickMemoWidgetExtension`にチェックを入れる

## 5. テスト手順

### ビルドとインストール
1. デバイスまたはシミュレータを選択
2. メインアプリをビルド＆実行（Cmd+R）
3. アプリが起動したら一度終了

### ウィジェット追加
1. ホーム画面を長押し
2. **+**ボタンをタップ
3. **Quick Memo**を検索
4. ウィジェットサイズを選択して追加

### 動作確認
1. ウィジェットのカテゴリボタンをタップ
2. アプリが開き、該当カテゴリのメモ入力画面が表示されることを確認

## トラブルシューティング

### ウィジェットが表示されない場合
- Widget Extensionのスキームを選択してビルド
- デバイスを再起動
- アプリを削除して再インストール

### データが共有されない場合
- App Groupsの設定を確認
- 両方のターゲットで同じgroup IDを使用しているか確認
- UserDefaultsのsuitNameが正しいか確認

### URL Schemeが動作しない場合
- Info.plistにURL Typesが正しく設定されているか確認
- quickmemoAppApp.swiftのonOpenURLが実装されているか確認