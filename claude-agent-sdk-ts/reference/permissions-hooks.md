# Permissions & hooks

> Type lookups below use `$DTS` (the resolved `sdk.d.ts`). Resolve once with `DTS=$(scripts/find-sdk-types.sh)` — see [getting-the-types.md](getting-the-types.md). The prose is version-stable; the fetched `.d.ts` is the source of truth.

This is the security and control surface. For any agent that runs unattended or
touches anything you care about, design this first.

## Layers, from coarse to fine

1. **Tool availability** — `tools` (which built-ins exist), `disallowedTools`
   (removed entirely). What the model can't see, it can't call.
2. **Auto-approval** — `allowedTools` lists tools that run without prompting.
3. **Permission mode** — `permissionMode` sets the default posture.
4. **Per-call decision** — `canUseTool` callback, the most precise control.
5. **Hooks** — `PreToolUse` / `PostToolUse` etc. for inspection, mutation, audit.

## `permissionMode`

```
'default'           // normal prompting behavior
'acceptEdits'       // auto-accept file edits, still gate other actions
'plan'              // planning only; no mutating actions (see planModeInstructions)
'dontAsk' / 'auto'  // reduced prompting / auto classifier
'bypassPermissions' // run everything, no gates — requires allowDangerouslySkipPermissions: true
```

`bypassPermissions` is for sandboxes you fully control. Prefer the `sandbox`
option (filesystem/network/credential limits) over bypass for unattended runs so
a mistake can't escape the box.

## `canUseTool` — programmatic per-call gate

```ts
import type { CanUseTool, PermissionResult } from "@anthropic-ai/claude-agent-sdk";

const canUseTool: CanUseTool = async (toolName, input, { signal }) => {
  // Allow reads anywhere, but confine writes/edits to /workspace.
  if (toolName === "Read" || toolName === "Grep" || toolName === "Glob") {
    return { behavior: "allow" };
  }
  if (toolName === "Write" || toolName === "Edit") {
    const path = String((input as any).file_path ?? "");
    if (!path.startsWith("/workspace/")) {
      return { behavior: "deny", message: "writes are restricted to /workspace" };
    }
    return { behavior: "allow", updatedInput: input };  // may also rewrite input
  }
  if (toolName === "Bash") {
    return { behavior: "deny", message: "shell disabled for this agent" };
  }
  return { behavior: "allow" };
};

query({ prompt, options: { canUseTool } });
```

`PermissionResult` is:
- `{ behavior: "allow", updatedInput?, updatedPermissions? }` — optionally rewrite
  the tool input or persist new permission rules.
- `{ behavior: "deny", message, interrupt? }` — the `message` is shown to the
  model so it can adapt; `interrupt: true` stops the whole run.

Runs **between** the model's `tool_use` request and execution — the right place
to enforce path allowlists, sanitize arguments, and audit. The model wanting to
call a tool is not permission to run it.

Grep exact types:
```sh
sed -n '/export declare type PermissionResult/,/};/p' "$DTS"
sed -n '/export declare type CanUseTool/,/;/p' "$DTS"
```

## Hooks

`options.hooks` maps a `HookEvent` to matchers of callbacks. Hooks observe and
can steer execution (add context, block, mutate). They overlap with `canUseTool`
for `PreToolUse` but cover a much wider set of lifecycle events.

```ts
options: {
  hooks: {
    PreToolUse: [{
      hooks: [async (input) => {
        // input is typed per event (PreToolUseHookInput): tool name, input, etc.
        if (input.tool_name === "Bash" && /rm -rf/.test(JSON.stringify(input.tool_input))) {
          return { decision: "block", reason: "destructive command blocked" };
        }
        return { continue: true };
      }],
    }],
  },
}
```

Available `HOOK_EVENTS` include (grep for the full list — it's long):
`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `UserPromptSubmit`,
`SessionStart`, `SessionEnd`, `Stop`, `SubagentStart`, `SubagentStop`,
`PreCompact`, `PostCompact`, `PermissionRequest`, `Notification`, … .

```sh
grep -n "HOOK_EVENTS" "$DTS"
grep -n "HookInput\|HookSpecificOutput\|HookJSONOutput" "$DTS"
```

Each event has its own typed input (`<Event>HookInput`) and output
(`<Event>HookSpecificOutput`). Read those before writing a non-trivial hook so
you return the right shape.

## Choosing between `canUseTool` and a `PreToolUse` hook

- Use **`canUseTool`** when the decision is "may this specific tool call run, and
  with what input?" — it's purpose-built for allow/deny + input rewrite.
- Use **hooks** when you need broader lifecycle coverage (session start context
  injection, post-tool auditing, compaction, prompt submission), or to react to
  events that aren't tool calls.
