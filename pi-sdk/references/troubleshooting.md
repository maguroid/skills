## 既知のハマりどころ

1. **サンドボックス・権限機構が一切ない**（公式 security.md 明記）。組み込みツールは
   pi プロセスの権限でファイル読み書き・シェル実行する。信頼できない入力を扱う
   自動実行では、ツールを渡さない設計にするか、コンテナ/VM で隔離すること
2. **auth.json のロック競合**（issue #1871）: 複数プロセス同時起動で
   "No API key found for openai-codex" という誤解を招くエラーが出ることがある。
   cron ではロックファイル等で多重起動を防ぐ
3. **ログイン直後に認証が検知されない**ことがある（issue #3287）。セットアップ
   スクリプトでは `/login` 後に認証確立を確認するステップ（再起動含む）を入れる
4. **MCP 非対応**は設計判断。必要なら Extension 機構でラップするか CLI ツール＋
   README で代替する
5. Skills 互換: `settings.json` で Claude Code / OpenAI Codex のスキルディレクトリを
   追加読み込みできる（互換範囲の詳細は要検証）
6. **単純な応答でも入力トークンは約6.5k**（システムプロンプト等）。`pi --mode json` の
   `message_end` イベントに usage（トークン・コスト）が入るので計測に使える
7. macOS には `timeout` コマンドがない。シェルから pi の暴走を防ぎたい場合は
   Node 側でタイムアウトを実装するか coreutils の `gtimeout` を使う
8. Codex サンドボックス等の制限環境で `npm install` すると `~/.npm` への書き込みで
   失敗することがある → `--cache ./.npm-cache` でリポジトリローカルのキャッシュを使う

## 主要ドキュメント

- SDK: https://pi.dev/docs/latest/sdk
- プロバイダ/認証: https://pi.dev/docs/latest/providers
- JSON モード: https://pi.dev/docs/latest/json / RPC: https://pi.dev/docs/latest/rpc
- 拡張: https://pi.dev/docs/latest/extensions / Skills: https://pi.dev/docs/latest/skills
- セキュリティ: https://pi.dev/docs/latest/security
- コンテナ化: packages/coding-agent/docs/containerization.md（リポジトリ内）
- 作者による設計思想: https://mariozechner.at/posts/2025-11-30-pi-coding-agent/
