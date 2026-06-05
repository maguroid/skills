# TypeScript SDK Patterns

## Version First

Always inspect the target project before coding:

```sh
rg -n "@modelcontextprotocol|McpServer|StdioServerTransport|StreamableHTTP" package.json pnpm-lock.yaml package-lock.json yarn.lock src test
```

If the project already uses an MCP SDK major version, follow that version's imports and APIs. The bundled stable v1 SDK uses these import subpaths:

- `@modelcontextprotocol/sdk/server/mcp.js`
- `@modelcontextprotocol/sdk/server/stdio.js`
- `@modelcontextprotocol/sdk/server/streamableHttp.js`
- `@modelcontextprotocol/sdk/client/index.js`
- `@modelcontextprotocol/sdk/client/stdio.js`
- `@modelcontextprotocol/sdk/client/streamableHttp.js`

The bundled SDK is the latest stable v1 release tag and uses the single `@modelcontextprotocol/sdk` package. Do not use v2 split-package imports unless the target project already uses v2 or the user explicitly asks for v2/prerelease work.

## Minimal v1 stdio Server

```ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import * as z from 'zod/v4';

const server = new McpServer({ name: 'example-server', version: '1.0.0' });

server.registerTool(
  'greet',
  {
    title: 'Greet',
    description: 'Greet a person by name.',
    inputSchema: { name: z.string().describe('Name to greet') },
  },
  async ({ name }) => ({
    content: [{ type: 'text', text: `Hello, ${name}!` }],
  }),
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

For stdio, send diagnostics to stderr, not stdout.

## Server Registration Patterns

### Tools

Use `registerTool` for model-invoked actions. Add `outputSchema` and `structuredContent` when callers need machine-readable results.

```ts
server.registerTool(
  'calculate-bmi',
  {
    title: 'BMI Calculator',
    description: 'Calculate Body Mass Index.',
    inputSchema: {
      weightKg: z.number(),
      heightM: z.number(),
    },
    outputSchema: { bmi: z.number() },
  },
  async ({ weightKg, heightM }) => {
    const output = { bmi: weightKg / (heightM * heightM) };
    return {
      content: [{ type: 'text', text: JSON.stringify(output) }],
      structuredContent: output,
    };
  },
);
```

For named structured outputs, prefer `type` aliases over interfaces when the SDK expects index-compatible objects.

### Tool Errors

Return `isError: true` when the tool ran but the domain operation failed.

```ts
return {
  content: [{ type: 'text', text: `HTTP ${res.status}: ${res.statusText}` }],
  isError: true,
};
```

### Resources

Use `registerResource` for read-only context.

```ts
server.registerResource(
  'config',
  'config://app',
  {
    title: 'Application Config',
    description: 'Application configuration.',
    mimeType: 'application/json',
  },
  async uri => ({
    contents: [{ uri: uri.href, text: JSON.stringify({ ok: true }) }],
  }),
);
```

Use `ResourceTemplate` for dynamic URI patterns and include a `list` callback when instances are discoverable.

### Prompts

Use `registerPrompt` for user-invoked reusable templates.

```ts
server.registerPrompt(
  'review-code',
  {
    title: 'Code Review',
    description: 'Review code for correctness and maintainability.',
    argsSchema: z.object({ code: z.string() }),
  },
  ({ code }) => ({
    messages: [
      {
        role: 'user' as const,
        content: { type: 'text' as const, text: `Review this code:\n\n${code}` },
      },
    ],
  }),
);
```

## Streamable HTTP Server

Use Streamable HTTP for remote or multi-client servers. Prefer `createMcpExpressApp` for local Host header protection.

Key points:

- Use `sessionIdGenerator` for stateful sessions.
- Use `sessionIdGenerator: undefined` only for stateless servers.
- Expose MCP-specific headers when browser clients need CORS.
- Close all session transports during shutdown.
- Validate Host headers on localhost servers.

Read:

- `references/repos/typescript-sdk/docs/server.md`
- `references/repos/typescript-sdk/src/examples/server/simpleStreamableHttp.ts`
- `references/repos/typescript-sdk/src/examples/server/simpleStatelessStreamableHttp.ts`
- `references/repos/typescript-sdk/src/examples/server/honoWebStandardStreamableHttp.ts`

## Server-Initiated Requests

Declare or check matching client capabilities before using server-initiated requests.

- Sampling: call `server.server.createMessage(...)`.
- Elicitation: call `server.server.elicitInput(...)` or send `elicitation/create`.
- Roots: call `server.server.listRoots()` when the client supports roots.
- Logging: declare `{ capabilities: { logging: {} } }` and call `server.sendLoggingMessage(..., extra.sessionId)`.

Never request secrets through form elicitation.

## Minimal v1 Client

```ts
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const client = new Client({ name: 'example-client', version: '1.0.0' });
const transport = new StreamableHTTPClientTransport(new URL('http://localhost:3000/mcp'));

await client.connect(transport);

try {
  const result = await client.callTool({
    name: 'greet',
    arguments: { name: 'Ada' },
  });

  if (result.isError) {
    console.error('Tool error:', result.content);
  } else {
    console.log(result.content);
  }
} finally {
  await transport.terminateSession?.();
  await client.close();
}
```

For local process-spawned servers, use `StdioClientTransport` from `@modelcontextprotocol/sdk/client/stdio.js`.

## Client Discovery

Loop on `nextCursor` for paginated list calls:

```ts
const allTools = [];
let cursor: string | undefined;

do {
  const page = await client.listTools({ cursor });
  allTools.push(...page.tools);
  cursor = page.nextCursor;
} while (cursor);
```

Apply the same pattern to resources, resource templates, and prompts.

## Client Server-Initiated Handlers

Declare capabilities and register handlers when the client supports server-initiated flows.

```ts
const client = new Client(
  { name: 'example-client', version: '1.0.0' },
  {
    capabilities: {
      sampling: {},
      elicitation: { form: {} },
      roots: {},
    },
  },
);

client.setRequestHandler('sampling/createMessage', async request => ({
  model: 'local-policy-model',
  role: 'assistant' as const,
  content: { type: 'text' as const, text: 'Response from the client model' },
}));

client.setRequestHandler('elicitation/create', async request => {
  if (request.params.mode === 'form') {
    return { action: 'decline' as const };
  }
  return { action: 'decline' as const };
});

client.setRequestHandler('roots/list', async () => ({
  roots: [{ uri: 'file:///path/to/workspace', name: 'Workspace' }],
}));
```

## Client Error Handling

Handle both tool-level failures and thrown SDK/protocol failures.

```ts
import { McpError } from '@modelcontextprotocol/sdk/types.js';

try {
  const result = await client.callTool({ name: 'fetch-data', arguments: { url } });
  if (result.isError) {
    console.error('Tool error:', result.content);
    return;
  }
} catch (error) {
  if (error instanceof McpError) {
    console.error(`MCP error ${error.code}: ${error.message}`);
  } else {
    throw error;
  }
}
```

## Tests And Smoke Checks

Prefer tests that exercise protocol behavior, not only handler internals:

- Instantiate server and client with in-memory or stdio transports when available.
- Verify `listTools`, `callTool`, `listResources`, `readResource`, `listPrompts`, and `getPrompt` behavior.
- Verify `isError` results for expected domain failures.
- Verify missing capability paths fail clearly.
- For HTTP, test session handling, auth, Host validation, CORS headers, shutdown, and reconnect/resumption behavior when relevant.
