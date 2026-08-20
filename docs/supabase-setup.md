# Supabase 開発セットアップ

## 現在のプロジェクト

- プラン: Free
- リージョン: 東京（`ap-northeast-1`）
- 用途: chocoLOG の認証・友人関係・共有履歴の保存
- 初版の正データ: 端末内 Drift/SQLite

Supabase は共有用の複製として利用する。通信失敗や無料プロジェクトの一時停止が発生しても、ローカルの記録入力を止めない。

## Flutter 側

`supabase_flutter` で起動時に接続する。URL と Publishable Key は `SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEY` の `--dart-define` で差し替えられる。Publishable Key はクライアントに含めてよいキーだが、Service Role Key や秘密鍵はアプリへ絶対に含めない。

例:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

## Google ログインを有効にする

1. Google Cloud Console で OAuth クライアントを作成する。
2. Supabase Dashboard の Authentication > Providers > Google に Client ID と Client Secret を登録する。
3. Supabase の Redirect URL（`https://<project-ref>.supabase.co/auth/v1/callback`）を Google の承認済みリダイレクト URI に登録する。
4. アプリ側の `chocolog://login-callback/` を許可されたリダイレクト先に登録する。

Google Provider が未設定の間は、設定画面からのログイン操作はエラーになるが、未ログインの端末内記録はそのまま利用できる。

## DB マイグレーション

```bash
supabase link --project-ref <project-ref>
supabase db push
```

マイグレーションは `supabase/migrations/` に保存する。共有履歴の読み取りは、承認済みの友人または本人だけに許可する RLS を必須とする。
