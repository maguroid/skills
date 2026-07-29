---
name: mcp-typescript
description: Build, modify, debug, review, migrate, or update local knowledge for Model Context Protocol (MCP) servers and clients in TypeScript. Use whenever an agent implements an MCP server, client, transport, tool, resource, prompt, capability, authentication flow, SDK integration, MCP behavior test, or refreshes MCP specification or TypeScript SDK information. Use this TypeScript-only skill by default for MCP server construction.
---

# MCP TypeScript

## Core Rule

Use TypeScript and the official TypeScript SDK. Inspect the target project's installed MCP packages and read the matching bundled SDK docs/examples before coding. Do not infer an import path, API generation, or protocol era from memory.

Use v2.0.0 split packages for new implementations: `@modelcontextprotocol/server`, `@modelcontextprotocol/client`, and `@modelcontextprotocol/core` as needed. Preserve an existing v1 project unless the user explicitly requests a major upgrade; use its `@modelcontextprotocol/sdk/...` imports only as documented compatibility work.

SDK generation and wire era are independent. A v2 client remains on the legacy `initialize` handshake unless `versionNegotiation` opts into `2026-07-28`; modern servers use `createMcpHandler` or `serveStdio` and stateless/MRTR semantics.

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

## Implementation Principles

- Treat MCP as a protocol contract. Respect lifecycle or modern per-request metadata, capability negotiation, JSON-RPC methods, pagination, cancellation, and error surfaces.
- Before implementing server-side HTTP, present viable framework/runtime options and tradeoffs, recommend one, and obtain confirmation. Treat an explicit choice in the current turn as confirmation.
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
