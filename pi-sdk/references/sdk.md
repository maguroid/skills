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
