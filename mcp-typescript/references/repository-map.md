# Repository Map

The bundled repositories were cloned with `ghq` and copied into this skill so future agents can inspect them without network access.

## Bundled Tags

- `references/repos/modelcontextprotocol`: `modelcontextprotocol/modelcontextprotocol` tag `2025-11-25`, commit `38c84e9f`.
- `references/repos/typescript-sdk`: `modelcontextprotocol/typescript-sdk` tag `v1.29.0`, commit `e12cbd70`.

These are stable release tags. Do not replace bundled repositories with `main`, `draft`, RC, alpha, beta, or other prerelease tags unless the user explicitly requests prerelease coverage.

## Version Risk Notes

- The SDK bundle intentionally tracks stable `v1.29.0`, not v2 alpha tags. Use `@modelcontextprotocol/sdk/...` imports for new examples unless the target project already uses a different SDK version.
- The SDK supports protocol version negotiation across current stable spec versions. Still inspect `src/types.ts`, `src/spec.types.ts`, and `docs/protocol.md` before implementing version-sensitive behavior.
- Do not copy APIs from a prior v2 main bundle such as split packages (`@modelcontextprotocol/server`, `@modelcontextprotocol/client`) into v1 projects.
- Tasks are experimental in the SDK and may change; prefer ordinary tools unless the user specifically needs deferred or resumable work.

## MCP Specification Repository

Important paths:

- `README.md`: repository purpose and current schema location.
- `docs/docs.json`: Mintlify navigation and the currently marked latest spec version.
- `docs/docs/learn/architecture.mdx`: host/client/server architecture, protocol layers, primitives, lifecycle.
- `docs/docs/learn/server-concepts.mdx`: tools, resources, prompts, and control model.
- `docs/docs/learn/client-concepts.mdx`: elicitation, roots, sampling.
- `docs/docs/develop/build-server.mdx`: server development guide.
- `docs/docs/develop/build-client.mdx`: client development guide.
- `docs/docs/tutorials/security/security_best_practices.mdx`: security guidance.
- `docs/specification/<version>/`: versioned protocol specification.
- `schema/<version>/schema.ts`: TypeScript-first protocol schema.
- `schema/<version>/schema.json`: generated JSON Schema.

Useful searches:

```sh
rg -n "initialize|capabilities|notifications/initialized|protocolVersion" references/repos/modelcontextprotocol/docs/specification
rg -n "tools/list|tools/call|resources/read|prompts/get|pagination|completion" references/repos/modelcontextprotocol/docs/specification
rg -n "authorization|OAuth|DNS rebinding|Host|security|consent|secrets" references/repos/modelcontextprotocol/docs
```

## TypeScript SDK Repository

The bundled SDK is the latest stable v1 tag. Its public package is `@modelcontextprotocol/sdk`; imports use subpaths such as `@modelcontextprotocol/sdk/server/mcp.js`, not the v2 split packages.

Important paths:

- `README.md`: installation, quick start, package expectations, examples index.
- `docs/server.md`: server guide for transports, tools, resources, prompts, logging, progress, sampling, elicitation, roots, shutdown, DNS rebinding protection.
- `docs/client.md`: client guide for transports, auth, discovery, invocation, server-initiated requests, errors, middleware, resumption.
- `docs/capabilities.md`: sampling, elicitation, and experimental task execution.
- `docs/protocol.md`: ping, progress, cancellation, pagination, capability negotiation, and schema details.
- `src/examples/server/`: runnable server examples for Streamable HTTP, state, OAuth, schema libraries, elicitation, sampling, progress, tasks, and compatibility.
- `src/examples/client/`: runnable client examples for Streamable HTTP, OAuth, fallback, parallel calls, elicitation, tasks, and resumption.
- `src/server/mcp.ts`: high-level `McpServer` API.
- `src/server/index.ts`: lower-level server protocol implementation.
- `src/client/index.ts`: client implementation.
- `src/shared/protocol.ts`: JSON-RPC routing, request/response correlation, capability checks, transport management.
- `src/types.ts` and `src/spec.types.ts`: protocol types and generated spec types.

Useful searches:

```sh
rg -n "registerTool|registerResource|registerPrompt|ResourceTemplate|completable" references/repos/typescript-sdk
rg -n "StdioServerTransport|StreamableHTTPClientTransport|StreamableHTTPServerTransport|SSEClientTransport" references/repos/typescript-sdk
rg -n "isError|progressToken|onprogress|requestSampling|elicit|listRoots|sendRootsListChanged" references/repos/typescript-sdk
rg -n "createMcpExpressApp|hostHeaderValidation|Host|DNS rebinding|requireBearerAuth" references/repos/typescript-sdk
```
