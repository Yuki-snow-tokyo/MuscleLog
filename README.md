# 筋トレ手帳 — セットアップ手順（Supabase＋GitHub Pages）

作業時間は30分ほどです。費用はかかりません。

## フォルダの中身

| ファイル | 役割 |
|---|---|
| index.html | アプリ本体 |
| config.js | Supabase の接続先を書くファイル（手順4で編集） |
| supabase-setup.sql | データベースを作るSQL（手順2で実行） |
| sw.js / manifest.webmanifest / *.png | ホーム画面に追加するためのファイル |

---

## 1. Supabase のプロジェクトを作る

1. https://supabase.com でアカウントを作ります（GitHub アカウントでログインできます）。
2. 「New project」を押し、以下のように設定します。
   - Region：**Northeast Asia (Tokyo)**
   - Database Password：長いランダムな文字列にします。アプリでは使わないので、パスワード管理ツールに保存しておけば十分です。
   - プラン：**Free**

## 2. テーブルを作る

1. 左メニューの「SQL Editor」を開きます。
2. `supabase-setup.sql` の中身を全部貼り付けて「Run」を押します。

このSQLで、次の3つが作られます。
- 記録を保存するテーブル（1ユーザー1行）
- 本人しか読み書きできない行レベルセキュリティ
- 1日1回・30日分の自動スナップショット（誤操作したときの保険）

## 3. 自分のアカウントを作り、新規登録を締め切る

1. 「Authentication → Users」を開き、「Add user → Create new user」を選びます。
   - メールアドレスと強いパスワードを入力し、**Auto Confirm User にチェック**を入れます。
2. 「Authentication → Sign In / Providers」を開き、次のように設定します。
   - **「Allow new users to sign up」をオフ**にします。これで、URLを知っていても誰も新しくアカウントを作れなくなります。
   - Email プロバイダは有効のままにしておきます。

## 4. config.js に接続先を書く

1. 「Project Settings → API Keys」から **Publishable key**（`sb_publishable_…`）をコピーします。旧形式の anon key でも動きます。
2. Project URL（`https://xxxx.supabase.co`）をコピーします。「Project Settings → Data API」などに表示されています。
3. `config.js` を開き、`url` と `key` に貼り付けます。

> ⚠️ **secret key / service_role key は絶対に入れないでください。** それらはセキュリティ（RLS）を無視できる管理者用のキーです。
> Publishable key は公開される前提のキーで、見られても行レベルセキュリティがあるので他人は何もできません。

## 5. GitHub Pages で公開する

1. GitHub で新しいリポジトリを作ります（例：`kintore`）。無料プランで Pages を使うには **Public** にする必要があります。
2. 「Add file → Upload files」で、このフォルダの中身を全部アップロードします。
3. 「Settings → Pages」を開き、Source を「Deploy from a branch」、Branch を `main` / `(root)` にして保存します。
4. 数分後、`https://<ユーザー名>.github.io/kintore/` で開けるようになります。

> リポジトリが公開になるのが気になる場合は、Cloudflare Pages の「Direct Upload」を使えば非公開のまま無料で公開できます。
> なお、公開して困るもの（パスワードや secret key）はこのフォルダに入っていません。

## 6. パスワード再設定用の URL を登録する

「Authentication → URL Configuration」の **Site URL** に、手順5で確認した URL を入れます。

## 7. iPhone に入れる

1. Safari で URL を開き、ログインできることを確認します。
2. 共有ボタンから「ホーム画面に追加」を選びます。
3. ホーム画面のアイコンから起動し、**もう一度ログイン**します。iPhone ではホーム画面のアプリと Safari で保存領域が別になっているためです。

---

## 日々の使い方と仕組み

- 記録はまず端末に保存され、約1秒後にクラウドへ送られます。ジムで電波がなくても記録でき、つながったら自動で送信されます。
- 別の端末でアプリを開くと、最新の記録を取り込みます。
- 2台の端末の両方で未送信の変更がぶつかった場合は、どちらを残すか選ぶ画面が出ます。黙って上書きされることはありません。
- 「ツール」タブから、同期の状態確認、今すぐ同期、ログアウト、バックアップの書き出し（JSON / CSV）ができます。
- 以前の端末保存版を同じ URL で使っていた場合は、その記録を初回ログイン時にクラウドへ移します。別の URL で使っていた場合は、旧版で「バックアップを書き出す」を行い、新版の「読み込む」で取り込んでください。

## 注意点

- **無料プランは7日間ほぼアクセスがないと一時停止します。** Supabase からメールが届きます。管理画面の「Resume project」で再開でき、データは消えません。週1回以上使っていれば、まず止まりません。
- **パスワードを忘れたとき：** 「Authentication → Users」で自分のユーザーを選び、「Send password recovery」を押します。届いたメールのリンクを開くと、アプリに新しいパスワードの設定画面が出ます（手順6の設定が必要です）。

## 誤って消した記録を戻す（自動スナップショットからの復元）

SQL Editor で、まず残っているスナップショットを確認します。

```sql
select day, rev, saved_at, jsonb_object_length(data->'logs') as days
from public.app_data_history
order by day desc;
```

戻したい日を決めたら、次を実行します。`rev + 1` は、各端末に「更新があった」と気づかせるために必要です。

```sql
update public.app_data a
set data = h.data, rev = a.rev + 1
from public.app_data_history h
where h.user_id = a.user_id and h.day = '2026-09-20';  -- ← 戻したい日
```

その後、アプリを開き直すと復元された内容が表示されます。
