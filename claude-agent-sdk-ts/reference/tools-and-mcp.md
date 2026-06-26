# Custom tools & MCP servers

> Type lookups below use `$DTS` (the resolved `sdk.d.ts`) and `$TOOLS` (`sdk-tools.d.ts`). Resolve once with `DTS=$(scripts/find-sdk-types.sh)` — see [getting-the-types.md](getting-the-types.md). The prose is version-stable; the fetched `.d.ts` is the source of truth.

The SDK gives the agent capabilities beyond its built-ins through **MCP
servers**. The SDK's headline feature is *in-process* MCP servers: you define
tools as plain TypeScript functions, no separate process or transport.

## In-process custom tools: `tool()` + `createSdkMcpServer()`

```ts
import { tool, createSdkMcpServer, query } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const getWeather = tool(
  "get_weather",
  "Get the current weather for a city",
  { city: z.string().describe("City name, e.g. 'Tokyo'") },   // Zod raw shape
  async (args) => {
    const data = await fetchWeather(args.city);               // args is typed from the schema
    return {
      content: [{ type: "text", text: `${args.city}: ${data.tempC}°C` }],
    };                                                          // MUST be CallToolResult shape
  },
);

const weatherServer = createSdkMcpServer({
  name: "weather",
  version: "1.0.0",
  tools: [getWeather],
});

const q = query({
  prompt: "What's the weather in Tokyo?",
  options: {
    mcpServers: { weather: weatherServer },
    // The tool is exposed to the model as `mcp__weather__get_weather`.
  },
});
```

### `tool()` signature

```
tool(name, description, inputSchema, handler, extras?)
```

- `inputSchema` — a **Zod raw shape** (an object of Zod validators), not a full
  `z.object(...)`. The handler's `args` are inferred from it.
- `handler` — `async (args, extra) => CallToolResult`. The return **must** be
  `{ content: [...] }` (e.g. `[{ type: "text", text }]`). Returning a bare value
  is the #1 custom-tool bug.
- `extras` (optional): `{ annotations?, searchHint?, alwaysLoad? }`.
  - `alwaysLoad: true` keeps the tool in the prompt instead of deferring it
    behind tool-search (use sparingly; it costs context).

Grep for exact types:
```sh
grep -n "export declare function tool" "$DTS"
sed -n '/CreateSdkMcpServerOptions = {/,/};/p' "$DTS"
```

### Naming & permissions

In-process MCP tools are addressed as `mcp__<serverName>__<toolName>`. Reference
them that way in `allowedTools` / `disallowedTools` and in `canUseTool`. You can
gate a whole server with specs like `mcp__weather`, `mcp__weather__*`, or
`mcp__*`.

`createSdkMcpServer({ alwaysLoad: true })` forces *all* the server's tools to
always load (equivalent to `defer_loading: false`); per-tool `alwaysLoad` is
OR'd with it.

## External MCP servers

`mcpServers` also accepts the standard MCP transports — register them by config
object. The union (`McpServerConfig`) covers:

- **stdio** (`McpStdioServerConfig`) — spawn a command: `{ command, args, env }`.
- **SSE** (`McpSSEServerConfig`) — `{ type: 'sse', url, headers? }`.
- **HTTP** (`McpHttpServerConfig`) — `{ type: 'http', url, headers? }`.
- **SDK in-process** (`McpSdkServerConfigWithInstance`) — what `createSdkMcpServer`
  returns.

```ts
options: {
  mcpServers: {
    weather: weatherServer,                                  // in-process
    fs: { command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem", "/data"] }, // stdio
    docs: { type: "http", url: "https://example.com/mcp" },  // remote
  },
}
```

Grep the config union for exact fields:
```sh
grep -n "McpServerConfig\|McpStdioServerConfig\|McpHttpServerConfig\|McpSSEServerConfig" "$DTS"
```

## Built-in tools

The agent's built-in tools (Bash, Read, Edit, Write, Glob, Grep, WebFetch,
WebSearch, Task, etc.) have their own input/output schemas in
`$TOOLS` (the resolved `sdk-tools.d.ts`). Grep there when you need to know exactly what a
built-in tool accepts or returns (e.g. to validate a `canUseTool` decision or a
`PreToolUse` hook):

```sh
grep -n "Bash\|FileEdit\|FileWrite\|WebFetch" "$TOOLS"
```

## When to use a custom tool vs. Bash

Prefer a custom `tool()` when the action is well-defined, needs validated typed
inputs, talks to your own API/DB, or must be auditable/permission-gated cleanly.
Reach for Bash/built-ins when you genuinely want open-ended file/command access.
Narrow, typed tools are easier to secure than "let it run any shell command."
