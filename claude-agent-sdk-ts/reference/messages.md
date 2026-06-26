# Driving and consuming `query()`

> Type lookups below use `$DTS` (the resolved `sdk.d.ts`). Resolve once with `DTS=$(scripts/find-sdk-types.sh)` — see [getting-the-types.md](getting-the-types.md). The prose is version-stable; the fetched `.d.ts` is the source of truth.

## The output stream: `SDKMessage`

`query()` returns a `Query`, which is an `AsyncGenerator<SDKMessage>`. Iterate it
to run the agent. `SDKMessage` is a discriminated union on `type`. The ones you
handle most:

| `type` | Meaning |
|--------|---------|
| `"system"` | Lifecycle/info (init, status). `subtype` distinguishes them. |
| `"assistant"` | A full assistant message (text and/or tool_use blocks). |
| `"user"` | A user message — including **synthetic** ones carrying tool results. |
| `"result"` | **Terminal.** Final outcome. `subtype: "success"` → `result` holds the text; `subtype: "error_*"` → the run failed. Carries `usage`, cost, `duration_ms`, `num_turns`, `session_id`. |
| `"stream_event"` / partial | Only when `includePartialMessages: true` — token-level deltas for live UIs. |

Grep the full union and each variant's fields:
```sh
grep -n "export declare type SDK.*Message" "$DTS"
sed -n '/export declare type SDKResultMessage/,/};/p' "$DTS"
```

### Minimal consumption

```ts
import { query, type SDKMessage } from "@anthropic-ai/claude-agent-sdk";

const q = query({ prompt: "Summarize README.md", options: { maxTurns: 8 } });

for await (const msg of q) {
  switch (msg.type) {
    case "assistant":
      // msg.message.content is Anthropic-format content blocks
      break;
    case "result":
      if (msg.subtype === "success") console.log(msg.result);
      else console.error("agent failed:", msg.subtype);
      console.log("cost $", msg.total_cost_usd, "turns", msg.num_turns);
      break;
  }
}
```

Always let the loop reach `"result"`. Don't `break` after the first `"assistant"`
message — the agent is mid-workflow (see SKILL.md gotcha #2).

## Input modes

### 1. String prompt (single-shot)

```ts
query({ prompt: "Do the thing", options });
```

The generator runs one task to completion and finishes. No control methods are
usable. Best for batch/headless one-offs.

### 2. Streaming input (interactive / steerable)

Pass an `AsyncIterable<SDKUserMessage>`. This unlocks the `Query` control
methods and lets you feed multiple turns:

```ts
async function* turns(): AsyncIterable<SDKUserMessage> {
  yield { type: "user", message: { role: "user", content: "First task" }, parent_tool_use_id: null };
  // ...later, based on what you observed in the output stream...
  yield { type: "user", message: { role: "user", content: "Now do the next thing" }, parent_tool_use_id: null };
}

const q = query({ prompt: turns(), options });

// Drive output and control concurrently:
await q.setPermissionMode("acceptEdits");
// await q.interrupt();
// await q.setModel("opus");
for await (const msg of q) { /* ... */ }
```

`Query` control methods (streaming input only) — grep `$DTS` for
the `interface Query`:

- `interrupt()` — stop the current execution gracefully.
- `setPermissionMode(mode)` — change permission posture mid-session.
- `setModel(model?)` — switch models for subsequent turns.
- `setMcpPermissionModeOverride(server, mode)` — tighten a single MCP server
  (tighten-only; can't widen privilege).
- `setMaxThinkingTokens(...)` — deprecated; prefer the `thinking` option.

### `SDKUserMessage` shape

```ts
{
  type: "user",
  message: { role: "user", content: string | ContentBlock[] },
  parent_tool_use_id: string | null,
  // optional: priority: 'now'|'next'|'later', shouldQuery, ...
}
```

`shouldQuery: false` appends a message to the transcript **without** triggering
an assistant turn (it merges into the next real turn) — useful for injecting
context. Grep `SDKUserMessage` for the full optional field set.

## Cleanup

- Single-shot: the generator completing is the end; nothing to clean up.
- Long-running / streaming: wire `options.abortController` and call `abort()` to
  tear down the subprocess deterministically. `Query` is disposable — `for await`
  to completion or aborting both clean up the transport.
