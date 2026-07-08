---
name: pi-sdk
description: Build, embed, or automate the Pi coding agent (earendil-works/pi, formerly badlogic/pi-mono) — SDK usage (createAgentSession / defineTool), headless & cron execution (--mode json / rpc), and subscription OAuth auth (OpenAI Codex ChatGPT Plus/Pro, Anthropic Claude Pro/Max, GitHub Copilot). Use whenever a task involves Pi Agent, pi coding agent, @earendil-works/pi-* or @mariozechner/pi-* packages, pi.dev, embedding Pi in a Node/TypeScript app, LLM extraction via subscription auth, or the pi CLI. Carries the correct package names (the project was renamed), auth setup, and known pitfalls so agents don't implement against stale or wrong information.
---

# Pi SDK — Pi coding agent の組み込み・自動実行・サブスク認証

Pi は Mario Zechner 氏による OSS のコーディングエージェント。CLI としてだけでなく
SDK として Node/TypeScript プロセスに直接組み込める。このスキルは 2026-07 時点の
一次情報（pi.dev docs / GitHub / CHANGELOG）の結晶。**開発が非常に活発（数日おきに
リリース）なため、挙動が食い違ったら必ず現行ドキュメントで再確認すること**:
https://pi.dev/docs/latest / https://github.com/earendil-works/pi

## 最重要: パッケージ名（改名済み）

プロジェクトは `badlogic/pi-mono` から **`earendil-works/pi`** へ移管された。

- 使うべき npm パッケージ: **`@earendil-works/pi-coding-agent`**（SDK + CLI）、
  `@earendil-works/pi-ai`（マルチプロバイダ LLM API）、`@earendil-works/pi-agent-core`
- **`@mariozechner/pi-*` は DEPRECATED。絶対に使わない**（Web 上の古い記事・LLM の
  学習知識は旧名で書かれていることが多い）

## パッケージのレイヤー構造（coding-agent を選ぶ前に）

モノレポは4層（下→上）: `pi-ai`（マルチプロバイダLLM API）→ `pi-agent-core`（ツール実行
ループを持つ状態管理エージェント）→ `pi-coding-agent`（このスキルの主対象。コーディング
特化の組み込みツール＋認証永続化＋TUI＋各種実行モード）→ `pi-tui`（CLI描画）。
別リポジトリで `pi-orchestrator`（マルチエージェント統括、experimental・API不安定）もある。

**`pi-agent-core` を直接使うべき場面**: `read`/`write`/`edit`/`bash` などコーディング用
ツールが不要で、独自ドメインのツール（外部API呼び出し等）だけを持つ専用エージェントを
組みたいとき。ツール実行モード（`parallel`/`sequential`をツール単位で制御）や
`beforeToolCall`/`afterToolCall`/`shouldStopAfterTurn` などの細かいフックが必要なとき。
セッション永続化・TUI・サブスク認証といった `pi-coding-agent` の付帯機能が不要／邪魔
（自前アプリへの組み込みで独自の永続化層を使いたい等）なとき。

**認証は「丸ごと自前」にはならない**: `pi-agent-core` が乗る `pi-ai` 層に、プロバイダ
ごとの OAuth（Anthropic Claude Pro/Max・OpenAI Codex・GitHub Copilot、
`provider.auth.oauth.login()/refresh()/toAuth()`）と 25+ プロバイダの環境変数ベース
APIキー自動解決がすでに実装済み（`npx @earendil-works/pi-ai login` で単体ログインも
可能）。`pi-ai` のデフォルト `CredentialStore` は**インメモリ**なので、自分で書く必要が
あるのは `read`/`modify`/`delete` の3メソッドを持つファイルバックエンドの
`CredentialStore` 実装だけ（`pi-coding-agent` の `AuthStorage` はこれを
`~/.pi/agent/auth.json` に対して実装済みのもの。単体 import して流用する手もある）。

**`pi-coding-agent` を選ぶ実質的な理由**（bukken-watch/watson の実例）: コーディング用
組み込みツール一式は不要でも、認証の永続化・トークンリフレッシュを自作したくない場合、
`AuthStorage`/`ModelRegistry` をそのまま使うために選ばれている。ツールなし1回呼び出し
（下記「抽出・分類だけしたい場合」）のような用途なら、実は `pi-agent-core` 単体でも
十分書けることは念頭に置く。

## SDK の基本形

```bash
npm install @earendil-works/pi-coding-agent
```

```typescript
import { AuthStorage, createAgentSession, ModelRegistry, SessionManager } from "@earendil-works/pi-coding-agent";

const authStorage = AuthStorage.create();          // ~/.pi/agent/auth.json を読む
const modelRegistry = ModelRegistry.create(authStorage);

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),       // 永続化するなら .create(cwd)
  authStorage,
  modelRegistry,
});

session.subscribe((event) => {
  if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
    process.stdout.write(event.assistantMessageEvent.delta);
  }
});

await session.prompt("What files are in the current directory?");
```

カスタムツールは TypeBox スキーマで定義する:

```typescript
import { Type } from "typebox";
import { defineTool } from "@earendil-works/pi-coding-agent";

const myTool = defineTool({
  name: "my_tool",
  label: "My Tool",
  description: "Does something useful",
  parameters: Type.Object({
    input: Type.String({ description: "Input value" }),
  }),
  execute: async (_toolCallId, params) => ({
    content: [{ type: "text", text: `Result: ${params.input}` }],  // LLM が見る
    details: {},                                                    // UI 向け構造化データ
  }),
});

const { session } = await createAgentSession({ customTools: [myTool] });
```

- Node からの統合は、CLI のサブプロセス起動より `AgentSession` 直接利用が公式推奨。
- 組み込みツールは `read` / `write` / `edit` / `bash`（＋任意で `grep` / `find` / `ls`）のみ。
  MCP・サブエージェント・プランモードは設計判断として非搭載。
- 会話履歴は `session.agent.state.messages` で直接操作・分岐できる。

### 抽出・分類だけしたい場合（エージェントループ不要のパターン)

外部コンテンツからの構造化抽出（スクレイピング結果の解析など）では、ツールを一切
渡さない 1 回呼び出しにする。プロンプトインジェクション対策にもなる（ツールが
なければページ内の指示で行動する経路がない）。出力 JSON は自前でスキーマ検証する。

実戦検証済みの構成（v0.80.3、bukken-watch 実装で確認）:

- `createAgentSession` に **`noTools: "all"`** を渡す（型は `"all" | "builtin"`、
  `dist/core/sdk.d.ts` に実在）＋ `customTools: []`。これで全ツールが無効になる
- さらに独自 `ResourceLoader` を渡して extensions / skills / prompts / agents files を
  空返しにすると、ローカル設定の混入経路も断てる（ホストの `~/.pi` の拡張を拾わない）
- `SessionManager.inMemory(cwd)` と `SettingsManager.inMemory(partial)` で
  ファイルシステムに痕跡を残さない組み込みができる
- 出力の JSON パースは厳密に（前後の説明文やコードフェンスを許容すると LLM 出力の
  異常検知が遅れる）。zod なら `.strict()` を使い、数値は現実的なレンジも検証する
- 後始末は `unsubscribe()` と `session.dispose()` を finally で。**ただしそれでも
  プロセスが exit しないことがあるため、CLI の終端で明示的に `process.exit(0)`
  すること**（launchd / cron 実行でのハング防止に必須）

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

## ヘッドレス / 定期実行

- 単発の非対話実行: `pi --mode json "prompt"` — JSON Lines でイベントが流れる。
  例: `pi --mode json "List files" 2>/dev/null | jq -c 'select(.type == "message_end")'`
- プロセス統合: `pi --mode rpc` — stdin/stdout の JSONL 双方向プロトコル。
  行区切りは `\n` のみ（`\r\n` は末尾 `\r` 除去で許容。Unicode 改行類似文字を改行と
  みなす汎用ラインリーダーは使わないこと、と公式明記）
- Docker 化の公式例:

```dockerfile
FROM node:24-bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent
WORKDIR /workspace
ENTRYPOINT ["pi"]
```

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
