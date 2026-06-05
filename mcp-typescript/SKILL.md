---
name: mcp-typescript
description: Build, modify, debug, review, or update local knowledge for Model Context Protocol (MCP) servers and MCP clients in TypeScript. Use whenever Codex is asked to implement an MCP server, MCP client, MCP transport, MCP tool/resource/prompt, MCP capability, MCP authentication flow, MCP SDK integration, tests for MCP behavior, or to refresh/update/latest-ize MCP specification or TypeScript SDK information. This skill is TypeScript-only and should be used by default for any MCP server construction request.
---

# MCP TypeScript

## Core Rule

Use TypeScript and the official TypeScript SDK. Before coding, inspect the target project's installed MCP packages and read the matching bundled SDK docs/examples. Do not assume an import path or API generation from memory.

## Bundled Sources

Use these references as the local source of truth:

- `references/mcp-field-guide.md`: protocol concepts, contracts, security expectations, and primitive selection.
- `references/typescript-sdk-patterns.md`: server/client implementation patterns with the TypeScript SDK.
- `references/update-procedure.md`: how to refresh bundled MCP information from latest stable release tags.
- `references/repository-map.md`: where to look inside the bundled repositories.
- `references/repos/modelcontextprotocol/`: cloned MCP specification/documentation/schema repository.
- `references/repos/typescript-sdk/`: cloned TypeScript SDK repository.

For precise behavior, search the bundled repositories with `rg` before relying on summaries. Start with:

```sh
rg -n "registerTool|registerResource|registerPrompt|StreamableHTTP|Stdio|Client|capabilities|initialize|elicitation|sampling|roots" references/repos/typescript-sdk
rg -n "tools/list|tools/call|resources/read|prompts/get|initialize|capabilities|Streamable HTTP|stdio" references/repos/modelcontextprotocol
```

## Workflow

1. Identify whether the task is server-side, client-side, both, or a migration/review.
2. Check the target project's package manager and dependency versions. Preserve the existing SDK major version unless the user explicitly asks to upgrade.
3. Read the relevant bundled docs and examples:
   - Server: `references/typescript-sdk-patterns.md`, SDK `docs/server.md`, and `src/examples/server/`.
   - Client: `references/typescript-sdk-patterns.md`, SDK `docs/client.md`, and `src/examples/client/`.
   - Protocol details: `references/mcp-field-guide.md`, latest spec docs, and `schema/<version>/schema.ts`.
4. Choose primitives deliberately:
   - Tools for model-invoked actions.
   - Resources for read-only application-controlled context.
   - Prompts for user-invoked reusable interaction templates.
   - Client capabilities for server-initiated sampling, elicitation, roots, and logging support.
5. Choose transport deliberately:
   - stdio for local process-spawned servers.
   - Streamable HTTP for remote or multi-client servers.
   - Legacy SSE only when maintaining compatibility with older servers.
6. Implement with explicit schemas, typed outputs, useful descriptions, and capability declarations.
7. Validate through typecheck/tests and, for servers, an MCP Inspector or client smoke test when available.

## Implementation Principles

- Treat MCP as a protocol contract, not just a function-calling wrapper. Respect lifecycle initialization, capability negotiation, JSON-RPC methods, notifications, pagination, and cancellation/progress surfaces.
- Keep tool names stable, descriptive, and machine-friendly. Each tool should do one coherent action with a precise input schema and useful result.
- Return tool-level failures as tool results with `isError: true` when the tool ran but the operation failed. Reserve thrown/protocol errors for invalid protocol use, unsupported methods, and internal failures.
- Never collect secrets through form elicitation. Use URL/out-of-band flows for credentials, payment details, OAuth, API keys, or other sensitive inputs.
- Treat roots as advisory scoping, not a security boundary. Enforce real restrictions with filesystem permissions, sandboxing, auth, and server-side validation.
- For local HTTP servers, include DNS rebinding protection or an allow-list for Host headers.
- For clients, always handle both `result.isError` and thrown MCP/protocol/SDK errors such as `McpError`.
- For long-running operations, support progress where the client provides a progress token and obey cancellation signals where practical.
- Avoid inventing unsupported protocol methods. If a custom method is required, define capability expectations and check the SDK examples for custom-method patterns.

## Validation Checklist

- Run the project's TypeScript typecheck and focused tests.
- Confirm every exposed tool/resource/prompt has a clear title/description and schema.
- Confirm capability-dependent calls are only made after the peer declares support.
- Confirm paginated `list*` calls loop on `nextCursor` in clients.
- Confirm Streamable HTTP servers route sessions correctly, close transports on shutdown, and use appropriate CORS/Host handling.
- Confirm stdio servers log diagnostics to stderr, not stdout.
- Confirm generated code uses TypeScript only.

## Refreshing MCP Information

When the user asks to update or latest-ize MCP information, read `references/update-procedure.md` first. Track latest stable release tags, not `main`, `draft`, RC, alpha, beta, or other prerelease tags. Investigate version risk before replacing bundled repositories, then update `references/repository-map.md` with the selected tags and commits.
