---
name: pi-sdk
description: Build, embed, or automate the Pi coding agent (earendil-works/pi, formerly badlogic/pi-mono) — SDK usage (createAgentSession / defineTool), headless & cron execution (--mode json / rpc), and OpenAI Codex subscription (ChatGPT Plus/Pro OAuth) auth. Use whenever a task involves Pi Agent, pi coding agent, @earendil-works/pi-* or @mariozechner/pi-* packages, pi.dev, embedding Pi in a Node/TypeScript app, LLM extraction via Codex subscription auth, or the pi CLI. Carries the correct package names (the project was renamed), auth setup, and known pitfalls so agents don't implement against stale or wrong information.
---

# Pi SDK — Pi coding agent の組み込み・自動実行・Codex サブスク認証

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

## Codex サブスクリプション認証（ChatGPT Plus/Pro OAuth）

公式サポート。OpenAI 自身が「Codex for OSS」プログラムで公認している。

1. 対話モードで `pi` を起動し `/login` → プロバイダ `ChatGPT Plus/Pro (Codex)` を選択
2. 認証方式は **Browser OAuth** または **Device Code**（v0.77.0〜）。SSH 先や
   ヘッドレス環境ではデバイスコードを使う
3. トークンは `~/.pi/agent/auth.json`（パーミッション 0600）に保存され、期限切れ時は
   **自動リフレッシュ**される。cron 等の非対話実行はこのファイルがあれば動く
4. SDK からは `AuthStorage.create()` がこのファイルを読むため、CLI で一度ログイン
   しておけば追加設定は不要。auth.json 内のキーは `openai-codex`

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

## 主要ドキュメント

- SDK: https://pi.dev/docs/latest/sdk
- プロバイダ/認証: https://pi.dev/docs/latest/providers
- JSON モード: https://pi.dev/docs/latest/json / RPC: https://pi.dev/docs/latest/rpc
- 拡張: https://pi.dev/docs/latest/extensions / Skills: https://pi.dev/docs/latest/skills
- セキュリティ: https://pi.dev/docs/latest/security
- コンテナ化: packages/coding-agent/docs/containerization.md（リポジトリ内）
- 作者による設計思想: https://mariozechner.at/posts/2025-11-30-pi-coding-agent/
