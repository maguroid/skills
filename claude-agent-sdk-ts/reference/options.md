# `Options` — annotated field guide

> Type lookups below use `$DTS` (the resolved `sdk.d.ts`). Resolve once with `DTS=$(scripts/find-sdk-types.sh)` — see [getting-the-types.md](getting-the-types.md). The prose is version-stable; the fetched `.d.ts` is the source of truth.

`query({ prompt, options })` takes an `Options` object. This is a curated guide
to the fields you'll actually reach for. For the **complete** list and exact
types, grep the source:

```sh
sed -n '/export declare type Options = {/,/^};/p' "$DTS"
```

## Identity & behavior

| Field | Notes |
|-------|-------|
| `systemPrompt` | `string` (custom) \| `string[]` (with cache boundary) \| `{ type: 'preset', preset: 'claude_code', append?, excludeDynamicSections? }`. **Set this explicitly** — see SKILL.md gotcha #1. A bare custom string replaces the whole prompt; the preset opts into Claude Code's default. `excludeDynamicSections: true` keeps the prompt static for cross-user prompt caching. |
| `model` | Alias (`'opus'`, `'sonnet'`, `'haiku'`, `'fable'`) or full ID (`'claude-fable-5'`). Defaults to the CLI default. |
| `fallbackModel` | Comma-separated list tried in order if the primary is overloaded. |
| `cwd` | Working directory for the session. Defaults to `process.cwd()`. |
| `additionalDirectories` | Extra absolute paths the agent may access beyond `cwd`. |

## Tools (which exist)

| Field | Notes |
|-------|-------|
| `tools` | Base set of **built-in** tools. `string[]` = exactly these; `[]` = none; `{ type: 'preset', preset: 'claude_code' }` = full Claude Code toolset. Native builds may route search through Bash `find`/`grep`; list `Grep`/`Glob` explicitly if you need the dedicated tools. |
| `mcpServers` | `Record<string, McpServerConfig>` — register custom (in-process SDK), stdio, SSE, or HTTP MCP servers. See `tools-and-mcp.md`. |
| `toolAliases` | Redirect a model-emitted tool name to another, e.g. `{ Bash: 'mcp__workspace__bash' }` to run Bash inside a sandbox MCP. |

## Permissions (what's allowed)

| Field | Notes |
|-------|-------|
| `canUseTool` | Callback invoked before each tool runs; return allow/deny. The most flexible control. See `permissions-hooks.md`. |
| `allowedTools` | Tool names auto-approved without prompting. **Not** a restriction list. |
| `disallowedTools` | Tool names removed from context entirely (also blocks harness-internal calls, unlike aliasing). |
| `permissionMode` | `'default' \| 'acceptEdits' \| 'bypassPermissions' \| 'plan' \| 'dontAsk' \| 'auto'`. |
| `allowDangerouslySkipPermissions` | **Required** to be `true` when `permissionMode: 'bypassPermissions'`. |
| `sandbox` | Sandbox filesystem/network/credential config — prefer this over bypass for unattended runs. |

## Safety rails

| Field | Notes |
|-------|-------|
| `abortController` | Wire an `AbortController` to cancel and clean up. |
| `maxTurns` | Cap on agentic round-trips. Set this to prevent loops. |
| `maxBudgetUsd` / `taskBudget` | Cost / token budget ceilings. |

## Context & settings

| Field | Notes |
|-------|-------|
| `settingSources` | `('user'\|'project'\|'local')[]`. Which filesystem settings to load. `[]` = full isolation; **must include `'project'` to load `CLAUDE.md`**. Set explicitly — see SKILL.md gotcha #1. |
| `settings` | Inline settings (path or object) merged at the flag layer. |
| `managedSettings` | Policy-tier lockdown for embedding apps (filtered restrictive-only). |
| `agents` | `Record<string, AgentDefinition>` — define subagents. See `agents-sessions.md`. |
| `agent` | Apply a named agent's prompt/tools/model to the **main** thread. |
| `skills` | `'all' \| string[]` — enable skills. The single place to turn skills on (don't also add `'Skill'` to `allowedTools`). |
| `plugins` | Load plugins (custom commands, agents, skills, hooks). |

## Sessions

| Field | Notes |
|-------|-------|
| `resume` | Session ID to resume. Mutually exclusive with `continue`. |
| `continue` | Continue the most recent conversation in `cwd`. |
| `forkSession` | With `resume`, branch to a new session ID instead of appending. |
| `sessionStore` | Pluggable persistence (see `examples/session-stores` in the upstream repo for S3/Redis/Postgres). |

## Hooks & streaming

| Field | Notes |
|-------|-------|
| `hooks` | `Partial<Record<HookEvent, HookCallbackMatcher[]>>`. See `permissions-hooks.md`. |
| `includePartialMessages` | Emit `SDKPartialAssistantMessage` for token-level streaming UIs. |
| `thinking` / `effort` / `maxThinkingTokens` | Reasoning controls (model-dependent). |
| `onElicitation` | Handle MCP elicitation (form/URL-auth requests). |

For anything not listed here, grep the source — `Options` has many more
specialized fields (sandbox detail, dialog handling, checkpointing, etc.).
