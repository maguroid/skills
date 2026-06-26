# Subagents, skills, plugins & sessions

> Type lookups below use `$DTS` (the resolved `sdk.d.ts`). Resolve once with `DTS=$(scripts/find-sdk-types.sh)` — see [getting-the-types.md](getting-the-types.md). The prose is version-stable; the fetched `.d.ts` is the source of truth.

## Subagents

Define specialized agents the main agent can invoke via the `Agent`/`Task` tool.
Keys are agent names; values are `AgentDefinition`.

```ts
options: {
  agents: {
    "test-runner": {
      description: "Runs the test suite and reports failures",  // when to use it
      prompt: "You run tests and report results concisely.",     // its system prompt
      tools: ["Read", "Grep", "Glob", "Bash"],                   // restrict tools (omit = inherit)
      model: "haiku",                                            // alias or full ID; omit = inherit
    },
  },
}
```

`AgentDefinition` fields (grep for the full set):
```sh
sed -n '/export declare type AgentDefinition = {/,/};/p' "$DTS"
```
Notable ones: `disallowedTools`, `mcpServers`, `skills` (preload into the
subagent), `maxTurns`, `background` (fire-and-forget), `permissionMode`.

Why subagents: isolate context, give a narrow tool set to a risky job, run cheap
models for grunt work, parallelize. The `description` is what the main agent uses
to decide when to delegate — make it specific.

### Running an agent as the main thread

`options.agent: "<name>"` applies a defined agent's prompt/tools/model to the
**main** conversation (equivalent to the `--agent` CLI flag) — useful to ship one
configured persona without restructuring around delegation.

## Skills

Enable Claude Skills for the session with `options.skills`:

```ts
options: { skills: "all" }        // every discovered skill
options: { skills: ["pdf", "docx"] }   // only these; or "plugin:skill"
```

This is the **single** place to turn skills on — you do **not** also add `'Skill'`
to `allowedTools`. It's a context filter, not a sandbox: unlisted skills are
hidden from the model but their files remain readable via Read/Bash, so don't
store secrets in skill files. Omitting `skills` is *not* "skills off" — the CLI's
own defaults still apply.

## Plugins

`options.plugins` loads plugins that bundle custom commands, agents, skills, and
hooks. Grep `SdkPluginConfig` for the config shape.

## Sessions: resume, continue, fork

Every run has a `session_id` (on the `result` message and `system` init). Persist
it to continue later.

```ts
// Continue the most recent session in this cwd:
query({ prompt: "keep going", options: { continue: true } });

// Resume a specific session by ID:
query({ prompt: "follow-up", options: { resume: sessionId } });

// Branch instead of appending (leaves the original intact):
query({ prompt: "what-if", options: { resume: sessionId, forkSession: true } });
```

`continue` and `resume` are mutually exclusive. `resumeSessionAt` resumes at a
specific message.

### Session inspection & management

The SDK exports helpers for working with stored sessions (all grep-able in
`$DTS`):

- `listSessions(options?)`, `getSessionInfo(id)`, `getSessionMessages(id)`
- `renameSession(id, title)`, `tagSession(id, tag)`, `deleteSession(id)`
- `forkSession(id)`, `listSubagents(id)`, `getSubagentMessages(id, agentId)`

### Custom session storage

For server deployments you can plug in a `SessionStore` (`options.sessionStore`)
to persist sessions in S3/Redis/Postgres/etc. instead of the local filesystem.
The upstream repo's `examples/session-stores/` has reference implementations and
a conformance test suite — point the user there if they need durable multi-host
sessions:
- `InMemorySessionStore` is exported for tests/ephemeral use.
- Implement the `SessionStore` interface for a real backend.

```sh
grep -n "interface SessionStore\|InMemorySessionStore" "$DTS"
```
