## サブスクリプション認証（OAuth）

`/login` で選べるサブスク型プロバイダは3つ（`docs/providers.md` に明記）:

- **ChatGPT Plus/Pro (Codex)**
- **Claude Pro/Max**（Anthropic。2026-07-08 時点で pi v0.80.3 で確認済み）
- **GitHub Copilot**

いずれも共通の流れ:

1. 対話モードで `pi` を起動し `/login` → プロバイダを選択
2. Codex の認証方式は **Browser OAuth** または **Device Code**（v0.77.0〜）。SSH 先や
   ヘッドレス環境ではデバイスコードを使う
3. トークンは `~/.pi/agent/auth.json`（パーミッション 0600）に保存され、期限切れ時は
   **自動リフレッシュ**される。cron 等の非対話実行はこのファイルがあれば動く
4. SDK からは `AuthStorage.create()` がこのファイルを読むため、CLI で一度ログイン
   しておけば追加設定は不要。auth.json 内のキーは Codex が `openai-codex`

### Codex（ChatGPT Plus/Pro）

公式サポート。OpenAI 自身が「Codex for OSS」プログラムで公認している。

### Claude Pro/Max

Anthropic のサブスク認証も有効。**ただし課金の扱いが Claude Code と異なる**:
サードパーティハーネス（Pi 含む）からの利用は Claude Pro/Max プランの通常利用枠には
入らず、[extra usage](https://claude.ai/settings/usage) 扱いでトークン従量課金される
（`docs/providers.md` に明記: "Third-party harness usage draws from extra usage and is
billed per token, not against Claude plan limits"）。プラン内で使い放題という誤解を
しないこと。

API キー方式（30+ プロバイダ）も同じ auth.json に共存できる。`key` フィールドは
リテラルのほか `"$ENV_VAR"` やシェルコマンド `"!security find-generic-password ..."` も可。
