---
name: mcp-typescript
description: Build, modify, debug, review, migrate, or update local knowledge for Model Context Protocol (MCP) servers and clients in TypeScript. Use whenever an agent implements an MCP server, client, transport, tool, resource, prompt, capability, authentication flow, SDK integration, MCP behavior test, or refreshes MCP specification or TypeScript SDK information. Use this TypeScript-only skill by default for MCP server construction.
---

# MCP TypeScript

## Core Rule

Use TypeScript and the official TypeScript SDK. Inspect the target project's installed MCP packages and read the matching bundled SDK docs/examples before coding. Do not infer an import path, API generation, or protocol era from memory.

Use v2.0.0 split packages for new implementations: `@modelcontextprotocol/server`, `@modelcontextprotocol/client`, and `@modelcontextprotocol/core` as needed. Preserve an existing v1 project unless the user explicitly requests a major upgrade; use its `@modelcontextprotocol/sdk/...` imports only as documented compatibility work.

## Bundled Sources

- `references/mcp-field-guide.md`: protocol contracts, 2026-era changes, security, and primitive selection.
- `references/typescript-sdk-patterns.md`: v2-first implementation patterns and v1 compatibility boundary.
- `references/update-procedure.md`: stable-tag refresh procedure.
- `references/repository-map.md`: exact tags, commits, and source navigation.
- `references/repos/modelcontextprotocol/`: specification at stable `2026-07-28`.
- `references/repos/typescript-sdk-v2/`: SDK v2.0.0 release snapshot.
- `references/repos/typescript-sdk-v1/`: SDK v1.30.0 compatibility snapshot.

Search the matching snapshot before relying on a summary:

```sh
rg -n "createMcpHandler|serveStdio|versionNegotiation|registerTool|StreamableHTTP|server/discover" references/repos/typescript-sdk-v2
rg -n "McpServer|StdioServerTransport|StreamableHTTP|registerTool" references/repos/typescript-sdk-v1
rg -n "server/discover|subscriptions/listen|input_required|resultType|stateless|Mcp-Session-Id" references/repos/modelcontextprotocol/docs/specification/2026-07-28
```

## Workflow

1. Identify server, client, migration, or review scope. Inspect the package manager and installed SDK major version.
2. Select the SDK and protocol era deliberately. Default new code to v2 packages; do not upgrade an existing v1 project without an explicit request.
3. For 2026-07-28 wire behavior, opt in explicitly. On clients set `versionNegotiation` to `auto` or a `2026-07-28` pin. On servers use the v2 2026-capable entry points (`createMcpHandler` for HTTP or `serveStdio` for stdio) and implement the modern stateless/MRTR semantics. v2 alone does not change a client's default legacy `initialize` handshake.
4. Read the matching bundled docs: v2 `docs/get-started/`, `docs/serving/`, `docs/protocol-versions.md`; v1 `docs/server.md` or `docs/client.md`; protocol details in the specification and schema.
5. Choose primitives deliberately: tools for model-controlled actions, resources for read-only context, prompts for user-invoked templates.
6. Choose transport deliberately: stdio for local process-spawned servers; Streamable HTTP for remote or multi-client servers; legacy SSE only for explicit compatibility.
7. Before implementing a server-side HTTP framework, present viable framework/runtime options and tradeoffs, recommend one, and obtain confirmation. Treat an explicit framework choice in the current turn as confirmation and record it in work notes or the plan.
8. Implement explicit schemas, typed outputs, useful descriptions, capability checks, and the correct era-specific behavior.
9. Validate with typecheck/tests and an Inspector or client smoke test when available.

## Implementation Principles

- Treat MCP as a protocol contract. Respect lifecycle or modern per-request metadata, capability negotiation, JSON-RPC methods, pagination, cancellation, and error surfaces.
- Return a tool-level `isError: true` result when a tool ran but the domain operation failed. Use thrown/protocol errors for invalid protocol use, unsupported methods, and internal failures.
- In 2026-07-28, do not depend on `initialize`, `Mcp-Session-Id`, shared connection state, or resumable SSE. Encode only integrity-protected, expiry-bounded retry state in MRTR `requestState`.
- Do not collect secrets through form elicitation. Use URL/out-of-band flows for credentials, payments, OAuth, or API keys.
- Treat roots as advisory, not a security boundary. Enforce filesystem and authorization restrictions independently. Prefer direct provider integration over new Sampling/Roots/Logging use; those features are deprecated in 2026-07-28.
- For local HTTP servers, protect against DNS rebinding with framework protection or a Host allow-list. For stdio, write diagnostics only to stderr.
- Handle both `result.isError` and thrown SDK/protocol errors in clients. Loop over `nextCursor` for paginated lists.

## Validation Checklist

- Run the project's TypeScript typecheck and focused tests.
- Confirm every exposed tool/resource/prompt has a clear title/description and schema.
- Confirm capability-dependent and era-specific calls are gated correctly.
- Confirm 2026 HTTP handlers are stateless and do not emit/require session or resumability headers.
- Confirm cache scope/TTL and HTTP authorization headers do not leak data across authorization contexts.
- Confirm generated code uses TypeScript only.

## Refreshing MCP Information

For updates, read `references/update-procedure.md` first. Track only stable specification and SDK release tags; never select `main`, `draft`, RC, alpha, beta, or canary as a snapshot source or canonical reference. A stable upstream snapshot can contain a historical `draft/` directory; do not use it as a canonical reference. Record selected tags, short commits, package/version mapping, and version risk in `references/repository-map.md`.
