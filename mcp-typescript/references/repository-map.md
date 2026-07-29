# Repository Map

The bundled repositories are offline, `.git`-free snapshots of official stable releases. Do not replace them with `main`, `draft`, RC, alpha, beta, or canary sources unless the user explicitly asks for prerelease coverage.

## Bundled Releases

| Path | Official release/tag | Commit | Status and purpose |
| --- | --- | --- | --- |
| `references/repos/modelcontextprotocol` | `2026-07-28` | `5f5440bb` | Stable MCP specification source of truth |
| `references/repos/typescript-sdk` | `@modelcontextprotocol/server@2.0.0` (v2 workspace release) | `cc4b4161` | Stable v2.0.0 split-package default for new code |
| `references/compatibility/typescript-sdk-v1` | `1.30.0` | `2d889f2b` | Stable v1 compatibility reference only |

The versionless `typescript-sdk` path always denotes the current default SDK snapshot. The v2 workspace release publishes aligned `@modelcontextprotocol/client`, `core`, `server`, `node`, and framework packages at `2.0.0`; the representative server release tag identifies the shared commit. The v1 release uses the single `@modelcontextprotocol/sdk` package. Record the package tag, not an invented monorepo `v2.0.0` tag.

## Version Risk

- Use v2 split packages for new implementation; do not major-upgrade an existing v1 project without an explicit request.
- v2 supports both legacy and modern protocol eras. Its client defaults to the legacy `initialize` wire. Explicitly choose `versionNegotiation`, `createMcpHandler`, or `serveStdio` when supporting the 2026 wire.
- `2026-07-28` is materially incompatible at wire level: stateless `_meta`, `server/discover`, `resultType`, MRTR, and subscription streams replace session/direct-request assumptions. Test each advertised era.
- Sampling, Roots, and Logging are deprecated in the specification. Tasks are extension-negotiated. HTTP+SSE is compatibility-only, and modern streams are not resumable.

## Specification Repository

Read these paths first:

- `docs/specification/2026-07-28/basic/index.mdx`: JSON-RPC contract, stateless `_meta`, result types, cache behavior.
- `docs/specification/2026-07-28/basic/versioning.mdx`: protocol selection.
- `docs/specification/2026-07-28/basic/transports/streamable-http.mdx`: headers, sessions, authorization, streams, and non-resumption.
- `docs/specification/2026-07-28/basic/patterns/mrtr.mdx`: `input_required`, retry state, and security.
- `docs/specification/2026-07-28/server/discover.mdx`: discovery advertisement.
- `docs/specification/2026-07-28/server/resources.mdx`: resource behavior and subscriptions.
- `docs/specification/2026-07-28/deprecated.mdx`: Roots/Sampling/Logging deprecations.
- `schema/2026-07-28/schema.ts` and `schema.json`: protocol schema.

Useful searches:

```sh
rg -n "server/discover|input_required|resultType|subscriptions/listen|stateless" references/repos/modelcontextprotocol/docs/specification/2026-07-28
rg -n "Mcp-Session-Id|Last-Event-ID|MCP-Protocol-Version|cacheScope|ttlMs" references/repos/modelcontextprotocol/docs/specification/2026-07-28
```

## TypeScript SDK v2 Repository

Important paths:

- `docs/index.md` and `docs/get-started/`: v2 quick starts and package model.
- `docs/protocol-versions.md`: legacy/modern negotiation matrix and opt-in semantics.
- `docs/serving/stdio.md` and `docs/serving/http.md`: `serveStdio` and `createMcpHandler` entry points.
- `docs/servers/`: tools, resources, prompts, MRTR, notification, sampling, and errors.
- `docs/clients/`: connecting, calling, subscriptions, auth, middleware, and roots.
- `docs/migration/upgrade-to-v2.md`: codemod and manual migration boundary.
- `packages/client/`, `packages/server/`, and `packages/core/`: split public packages.
- `examples/`: executable v2 examples.

## TypeScript SDK v1 Compatibility Repository

Read only for a project already on v1:

- `docs/server.md`, `docs/client.md`, `docs/capabilities.md`, `docs/protocol.md`.
- `src/examples/server/` and `src/examples/client/`.
- `src/server/mcp.ts`, `src/client/index.ts`, and `src/types.ts`.

Do not copy v1 imports or session/direct-request patterns into v2 examples.
