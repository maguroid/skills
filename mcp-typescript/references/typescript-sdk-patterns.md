# TypeScript SDK Patterns

## Select The Generation First

Inspect the target project before coding:

```sh
rg -n "@modelcontextprotocol|McpServer|createMcpHandler|serveStdio|StdioServerTransport" package.json pnpm-lock.yaml package-lock.json yarn.lock src test
```

Use the v2.0.0 split packages for a new project. Use `@modelcontextprotocol/sdk/...` only in an existing v1 project that the user has not asked to upgrade. Do not mix generation imports in one example or source file.

| Scope | v2.0.0 default | v1.30.0 compatibility only |
| --- | --- | --- |
| Server | `@modelcontextprotocol/server` | `@modelcontextprotocol/sdk/server/mcp.js` |
| stdio server | `@modelcontextprotocol/server/stdio` | `@modelcontextprotocol/sdk/server/stdio.js` |
| Client | `@modelcontextprotocol/client` | `@modelcontextprotocol/sdk/client/index.js` |
| stdio client | `@modelcontextprotocol/client/stdio` | `@modelcontextprotocol/sdk/client/stdio.js` |
| HTTP client | `@modelcontextprotocol/client` | `@modelcontextprotocol/sdk/client/streamableHttp.js` |

## Minimal v2 Stdio Server

```ts
import { McpServer } from '@modelcontextprotocol/server';
import { serveStdio } from '@modelcontextprotocol/server/stdio';
import * as z from 'zod/v4';

void serveStdio(() => {
  const server = new McpServer({ name: 'example-server', version: '1.0.0' });

  server.registerTool(
    'greet',
    {
      title: 'Greet',
      description: 'Greet a person by name.',
      inputSchema: z.object({ name: z.string().describe('Name to greet') }),
    },
    async ({ name }) => ({
      content: [{ type: 'text', text: `Hello, ${name}!` }],
    }),
  );

  return server;
});
```

`serveStdio` is a 2026-capable entry point, but choosing v2 does not itself force modern wire behavior. Treat support for the 2026 era as an explicit product decision, test both eras when you advertise both, and write diagnostics only to stderr.

## v2 Server Registration

Use `registerTool`, `registerResource`, and `registerPrompt`. Give every public surface a title/description and schema. Add `outputSchema` and `structuredContent` when a consumer needs a machine-readable result.

```ts
server.registerTool(
  'calculate-bmi',
  {
    title: 'BMI calculator',
    description: 'Calculate Body Mass Index.',
    inputSchema: z.object({ weightKg: z.number(), heightM: z.number() }),
    outputSchema: z.object({ bmi: z.number() }),
  },
  ({ weightKg, heightM }) => {
    const output = { bmi: weightKg / (heightM * heightM) };
    return {
      content: [{ type: 'text', text: JSON.stringify(output) }],
      structuredContent: output,
    };
  },
);
```

Return `isError: true` when a tool executed but its domain action failed. Do not convert invalid protocol usage or unsupported methods into a successful-looking tool result.

## v2 HTTP And 2026 Wire

Before choosing Express, Fastify, Hono, a Web-standard runtime, or another framework, present options/tradeoffs and obtain the user's confirmation. Then use the selected framework adapter and read the matching `docs/serving/` guide.

Use `createMcpHandler` to expose the v2 HTTP entry. Its factory creates a server for the request and receives its era; do not put client identity, capabilities, or task/request state in process-local session state.

```ts
import { createMcpHandler, McpServer } from '@modelcontextprotocol/server';

const handler = createMcpHandler(({ era }) => {
  const server = new McpServer({ name: 'example-server', version: '1.0.0' });
  // Register stateless handlers. Branch only where legacy and modern behavior differs.
  return server;
});

// Adapt handler.fetch(request) to the confirmed HTTP framework/runtime.
```

The default handler additionally supports stateless legacy HTTP traffic. Use its `legacy` policy deliberately; reject legacy traffic only when compatibility is not promised. For modern connections, use MRTR helpers/patterns for additional input, `subscriptions/listen` for notification streams, and per-request metadata. Do not emit `Mcp-Session-Id` or `Last-Event-ID` behavior.

## Minimal v2 Client

```ts
import { Client, StreamableHTTPClientTransport } from '@modelcontextprotocol/client';

const client = new Client(
  { name: 'example-client', version: '1.0.0' },
  { versionNegotiation: { mode: 'auto' } },
);

await client.connect(
  new StreamableHTTPClientTransport(new URL('http://localhost:3000/mcp')),
);

try {
  const result = await client.callTool({
    name: 'greet',
    arguments: { name: 'Ada' },
  });
  if (result.isError) console.error('Tool error:', result.content);
  else console.log(result.content);
} finally {
  await client.close();
}
```

`versionNegotiation` is the client-side opt-in. The default remains the legacy `initialize` handshake. `mode: 'auto'` probes with `server/discover` and falls back; `{ pin: '2026-07-28' }` refuses fallback. Do not default a spawn-per-invocation stdio CLI to `auto`: its compatibility probe can launch an extra short-lived child and wait for a legacy timeout.

For local child processes import `StdioClientTransport` from `@modelcontextprotocol/client/stdio`. When using a cached discovery verdict, own its freshness policy; stale legacy verdicts can mask a server upgrade.

## Client Discovery, Pagination, And Errors

Loop over `nextCursor` for every paginated list. Handle `result.isError` as well as SDK/protocol errors thrown by `connect` or calls. Read the v2 package's error exports before naming an error class; v1 `McpError` is not the v2 default error API.

```ts
const allTools = [];
let cursor: string | undefined;
do {
  const page = await client.listTools({ cursor });
  allTools.push(...page.tools);
  cursor = page.nextCursor;
} while (cursor);
```

## v1 Compatibility Boundary

Keep existing v1 projects on `@modelcontextprotocol/sdk` and follow `references/compatibility/typescript-sdk-v1/docs/server.md` or `docs/client.md`. The legacy stdio shape is `server.connect(new StdioServerTransport())`; its Streamable HTTP/session APIs, direct server-initiated requests, and import subpaths are not templates for new v2 code.

When the user requests a v1-to-v2 migration, run the official v2 codemod from the package root, resolve its markers, typecheck, format, and test. Then separately decide whether to opt into `2026-07-28`; an SDK-major migration does not imply a wire-protocol migration.

## Tests And Smoke Checks

- Prefer a linked in-memory or stdio client/server test that covers list and invocation behavior.
- Verify expected domain failures return `isError`.
- Verify capability, pagination, and era-specific behavior.
- For HTTP, test the confirmed framework integration, Host/DNS-rebinding handling, CORS, authorization, shutdown, and both advertised eras.
