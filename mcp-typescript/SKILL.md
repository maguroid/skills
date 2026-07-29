---
name: mcp-typescript
description: Build, modify, debug, review, migrate, or update local knowledge for Model Context Protocol (MCP) servers and clients in TypeScript. Use whenever an agent implements an MCP server, client, transport, tool, resource, prompt, capability, authentication flow, SDK integration, MCP behavior test, or refreshes MCP specification or TypeScript SDK information. Use this TypeScript-only skill by default for MCP server construction.
---

# MCP TypeScript

## Core Rule

Use TypeScript and the official TypeScript SDK. Before coding, inspect the target project's package manifest, lockfile, installed package exports, and types. Read only the relevant bundled official documentation. Do not infer an import path, SDK generation, or protocol era from memory.

Use v2.0.0 split packages for new implementations: `@modelcontextprotocol/server`, `@modelcontextprotocol/client`, and `@modelcontextprotocol/core` as needed. Preserve an existing v1 project unless the user explicitly requests a major upgrade; use its `@modelcontextprotocol/sdk/...` imports only as documented compatibility work.

SDK generation and wire era are independent. A v2 client remains on the legacy `initialize` handshake unless `versionNegotiation` opts into `2026-07-28`; modern servers use `createMcpHandler` or `serveStdio` and stateless/MRTR semantics.

## Official References

- `references/specification/docs/`: stable MCP `2026-07-28` specification.
- `references/specification/schema.ts` and `schema.json`: normative protocol schema.
- `references/typescript-sdk/docs/`: official TypeScript SDK v2.0.0 documentation.
- `references/sources.md`: exact upstream tags, commits, licenses, and snapshot boundaries.

Read the specification for wire behavior and the SDK documentation for public APIs. Search before relying on memory:

```sh
rg -n "createMcpHandler|serveStdio|versionNegotiation|registerTool|StreamableHTTP|server/discover" references/typescript-sdk/docs
rg -n "server/discover|subscriptions/listen|input_required|resultType|stateless|Mcp-Session-Id" references/specification
```

For an existing v1 project, treat its installed package and types as authoritative. If they are insufficient, fetch the matching official stable tag; do not substitute the bundled v2 documentation or a different fixed v1 release.

## HTTP Framework Selection

Before implementing server-side HTTP, present viable framework/runtime options and tradeoffs, recommend one, and obtain confirmation. Treat an explicit choice in the current turn as confirmation.

## Refreshing MCP Information

Track only official stable specification and SDK release tags. Never select `main`, `draft`, RC, alpha, beta, or canary as a snapshot source or canonical reference. Replace only the bundled specification docs/schema and SDK docs, retain the upstream licenses, and record exact tags, commits, and included paths in `references/sources.md`. Do not bundle repository history, source, examples, tests, site infrastructure, or compatibility snapshots.
