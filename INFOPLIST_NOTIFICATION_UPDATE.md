# 通知権限の設定手順

QuickMemoで通知機能を使用するため、以下の設定をXcodeで行う必要があります。

## 設定手順

1. Xcodeでプロジェクトを開く
2. quickMemoAppターゲットを選択
3. "Build Settings"タブを開く
4. 検索バーで"Info.plist"を検索
5. "Info.plist Values"セクションを見つける
6. "＋"ボタンをクリックして新しいエントリを追加
7. 以下を設定:
   - Key: `INFOPLIST_KEY_NSUserNotificationsUsageDescription`
   - Value: `メモを書くことを思い出させるための通知を送信します`

または

1. Info.plistファイルを直接編集
2. 以下のエントリを追加:
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>メモを書くことを思い出させるための通知を送信します</string>
```

## 注意事項

- この設定がないと、通知権限のリクエストが正しく動作しません
- アプリをApp Storeに提出する際、この説明文が審査対象になります
- 説明文は、なぜ通知を使用するのかをユーザーに明確に伝える必要があります

## 確認方法

1. アプリを実行
2. 設定画面でPro版の通知設定をオン
3. システムの通知許可ダイアログが表示されることを確認
4. 設定した説明文が表示されることを確認