---
name: claude-agent-sdk-ts
description: >-
  Build, debug, or review AI agents with the Claude Agent SDK for TypeScript
  (the `@anthropic-ai/claude-agent-sdk` npm package, formerly the Claude Code
  SDK). Use this whenever the task involves the `query()` function, defining
  custom tools with `tool()` / `createSdkMcpServer()`, wiring MCP servers,
  permission control (`canUseTool`, `permissionMode`), hooks, subagents,
  skills, sessions/resume, or consuming the SDK's streaming `SDKMessage`
  output — even if the user only says "agent SDK", "claude-agent-sdk", "build
  an agent in Node/TypeScript", or pastes code importing from
  `@anthropic-ai/claude-agent-sdk`. Carries the mental model, best practices,
  and common pitfalls, plus how to pull the real type definitions for the exact
  version in play — so you build on the actual API instead of guessing.
---

# Claude Agent SDK (TypeScript)

The Claude Agent SDK lets you programmatically run an agent with Claude Code's
capabilities — reading/editing files, running commands, calling tools, managing
sessions — from a Node/TypeScript program. This skill helps you build such
agents **correctly and idiomatically**.

The SDK releases frequently, so this skill deliberately does **not** vendor the
type definitions — a bundled copy would go stale. Instead it carries the durable
parts (mental model, best practices, pitfalls) and tells you how to fetch the
**real** types for whatever version is in play. The prose is the map; the fetched
`.d.ts` is the source of truth for exact field names, enums, and defaults.

## How to use this skill

1. Read the **Mental model** and **Gotchas** below first — they prevent the most
   common mistakes (wrong defaults, blocking the stream, leaking permissions).
2. For any specific API, **grep the real type definitions** rather than guessing.
   The types live in the npm package, not bundled here — resolve a copy first
   (see `reference/getting-the-types.md`):
   ```sh
   DTS=$(scripts/find-sdk-types.sh)   # project's installed copy, else fetches latest
   grep -n "permissionMode" "$DTS"
   sed -n '/export declare type Options = {/,/^};/p' "$DTS"
   ```
3. Open the focused reference file for the area you're working on (see map below).
4. Copy from `examples/` as a starting point.

## Which version to trust

The SDK's `.d.ts` files ship inside the npm package. The authoritative version
depends on where the code runs:

1. **Working in a project that has the SDK installed** → that project's
   `node_modules/@anthropic-ai/claude-agent-sdk/sdk.d.ts` is the source of truth
   (it's what the code compiles against).
2. **Greenfield / advice / no install** → use the latest published version;
   confirm with the user if a specific version is pinned.

`scripts/find-sdk-types.sh` applies that precedence for you (installed copy, else
download into a local cache) and prints the path. Full details and manual
fallbacks are in `reference/getting-the-types.md`.

**Version-stable vs. not:** this skill's prose (mental model, gotchas, recipes)
rarely changes between releases — trust it. Exact field names, enum members, and
especially **defaults** (e.g. `systemPrompt` / `settingSources`) are
version-specific — never assert them from memory; grep the fetched `.d.ts`.

## Reference map

| File | When to read it |
|------|-----------------|
| `reference/getting-the-types.md` | **How to fetch the real `sdk.d.ts` / `sdk-tools.d.ts`** and which version to use. Start here for any API lookup. |
| `reference/options.md` | Annotated guide to the most-used `Options` fields. |
| `reference/messages.md` | The `SDKMessage` stream — how to drive and consume `query()`. |
| `reference/tools-and-mcp.md` | Custom tools with `tool()`, in-process & external MCP servers. |
| `reference/permissions-hooks.md` | `canUseTool`, `permissionMode`, settings, and hooks. |
| `reference/agents-sessions.md` | Subagents, skills, plugins, and session resume/fork. |
| `scripts/find-sdk-types.sh` | Resolve & print a usable `sdk.d.ts` path (installed or fetched). |

## Setup

```sh
npm install @anthropic-ai/claude-agent-sdk   # Node 18+
```

The SDK spawns the Claude Code CLI as a subprocess under the hood, so it needs
credentials available to that process. Pick one:

- `ANTHROPIC_API_KEY` env var (Anthropic API), or
- An existing Claude Code subscription login (the CLI's stored OAuth), or
- A third-party provider via env (`CLAUDE_CODE_USE_BEDROCK=1` + AWS creds, or
  `CLAUDE_CODE_USE_VERTEX=1` + gcloud ADC).

Note `env` in `Options` **replaces** the subprocess environment when set — spread
`process.env` yourself if the child still needs `PATH`/`HOME`/`ANTHROPIC_API_KEY`.

## Mental model

`query()` is the one entry point. Everything else configures it.

```ts
import { query } from "@anthropic-ai/claude-agent-sdk";

const q = query({
  prompt: "List the TODOs in this repo",
  options: { /* see reference/options.md */ },
});

for await (const message of q) {
  // message: SDKMessage — a discriminated union on `message.type`
  if (message.type === "result") {
    console.log(message.result);   // final text (on success)
  }
}
```

Key facts that shape every design decision:

- **`query()` returns a `Query`, which is an `AsyncGenerator<SDKMessage>`.** You
  *must* iterate it to make the agent run; nothing happens until you consume the
  stream. The terminal message is `type: "result"` (an `SDKResultMessage` carrying
  the final text, `usage`, cost, and `subtype: "success" | "error_*"`).

- **Two input modes, and the choice is architectural:**
  - **String prompt** → single-shot. Simplest; the turn ends and the generator
    completes.
  - **`AsyncIterable<SDKUserMessage>` prompt** → streaming input. This is what
    unlocks the `Query` control methods — `interrupt()`, `setPermissionMode()`,
    `setModel()`, `setMcpPermissionModeOverride()` — and multi-turn / interactive
    agents. If you need to steer the agent mid-run, you need streaming input.
    See `reference/messages.md`.

- **The agent has real, powerful built-in tools** (Bash, Edit, Write, Read,
  WebFetch, etc.). Treat tool access and permissions as a security boundary, not
  an afterthought — see Gotchas and `reference/permissions-hooks.md`.

- **Custom capabilities are added as in-process MCP tools** via `tool()` +
  `createSdkMcpServer()`. No separate process needed. See
  `reference/tools-and-mcp.md`.

## Gotchas (read before writing code)

These are the failures that bite people, in rough order of frequency:

1. **Don't rely on default `systemPrompt` / `settingSources` — set them
   explicitly.** The Agent SDK's defaults differ from the Claude Code CLI and
   have shifted across versions. The headline difference from the old Code SDK:
   the Agent SDK does **not** assume the `claude_code` system prompt or auto-load
   your filesystem settings/`CLAUDE.md`. If you want Claude-Code-like behavior,
   opt in:
   ```ts
   options: {
     systemPrompt: { type: "preset", preset: "claude_code" },
     settingSources: ["project"],   // needed to load CLAUDE.md; [] = full isolation
   }
   ```
   For a purpose-built agent, prefer a plain custom string prompt and `[]`
   setting sources so behavior is reproducible and not host-dependent. Verify the
   exact current default by reading the `settingSources` / `systemPrompt` doc
   comments in the fetched `sdk.d.ts` (see `reference/getting-the-types.md`).

2. **Iterate the whole stream; don't `break` early on the first assistant
   message.** The agent runs across multiple turns of tool use. The run isn't
   done until you see `type: "result"`. Breaking early leaves the subprocess
   working and resources unclosed. To stop deliberately, call `q.interrupt()`
   (streaming mode) or abort via `options.abortController`.

3. **Permissions are the security boundary.** By default tools may prompt; in a
   headless/server context there's no human to answer. Decide deliberately:
   - Use `canUseTool` to programmatically allow/deny each call (return
     `{ behavior: "allow" }` or `{ behavior: "deny", message }`).
   - Or constrain with `allowedTools` / `disallowedTools` / `tools`.
   - `permissionMode: "bypassPermissions"` runs everything unattended and
     **requires** `allowDangerouslySkipPermissions: true`. Only do this in a
     sandbox you control. Never point a bypassed agent at a path or network you
     can't afford to have mutated.

4. **`tools: []` disables *built-in* tools but not your MCP tools.** To give an
   agent *only* your custom tools, set `tools: []` and register your MCP server;
   to get the full Claude Code toolset use `tools: { type: "preset", preset:
   "claude_code" }`. Don't confuse `tools` (which built-ins exist) with
   `allowedTools` (which are auto-approved).

5. **`maxTurns` and `abortController` are your safety rails.** An agent left
   without a turn cap can loop. Set `maxTurns`, and wire an `AbortController`
   (and/or `maxBudgetUsd`) for runaway protection.

6. **Custom tool handlers must return MCP `CallToolResult` shape**, i.e.
   `{ content: [{ type: "text", text: "..." }] }`, not a bare value. The `tool()`
   helper types this for you — follow it.

7. **The model emitting a tool call ≠ permission to run it.** `canUseTool` and
   hooks (`PreToolUse`) run *between* the model's request and execution. That's
   where you sanitize inputs, enforce path allowlists, and audit.

## Quick recipes

- **One-shot question:** see `examples/single-shot.ts`.
- **Interactive / steerable agent:** see `examples/streaming-input.ts`.
- **Give the agent a custom tool:** see `examples/custom-tool-server.ts`.
- **Lock down what the agent may do:** see `examples/permissions-and-hooks.ts`.

When in doubt about a field's type, exact enum values, or whether an option
exists in the version in play: **fetch and grep the real `sdk.d.ts`**
(`DTS=$(scripts/find-sdk-types.sh)`; see `reference/getting-the-types.md`). The
types are the source of truth; this document is the map.
