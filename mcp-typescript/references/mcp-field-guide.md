# MCP Field Guide

## Contract And Era

MCP is JSON-RPC 2.0 for context exchange between a host/client and a server. Use the versioned schema as the contract when prose and SDK examples differ.

The bundled stable specification is `2026-07-28`. It begins the **modern** era. Earlier revisions through `2025-11-25` are the **legacy** era. Do not accidentally combine them.

| Concern | Legacy wire | 2026-07-28 wire |
| --- | --- | --- |
| Bootstrap | `initialize` then `notifications/initialized` | `server/discover` advertisement or an inline request with `_meta` |
| State | Session/connection-oriented | Stateless: each request supplies required protocol version and client capabilities in `_meta`; client info is optional/SHOULD be supplied |
| HTTP session | `Mcp-Session-Id` | Do not mint, require, or echo it; ignore a received legacy header |
| Server-to-client work | Direct server-initiated requests | MRTR `input_required`; client retries the original request with `inputResponses` and `requestState` |
| Result shape | Prior result schema | Every result has `resultType`; absent means `complete` only for older-server compatibility |
| Updates | Unsolicited notifications/subscription APIs | `subscriptions/listen` stream filtering |
| Resumption | Legacy SSE/session techniques | No `Last-Event-ID` stream resumption |

The v2 SDK supports both eras. A v2 client remains legacy by default. Use `versionNegotiation: { mode: 'auto' }` to probe `server/discover` then fall back, or pin `2026-07-28` when fallback is unacceptable. On servers, use `createMcpHandler` (HTTP) or `serveStdio` (stdio) for the modern-capable entry points and design handlers as stateless.

## Wire Versus SDK Public API

`resultType` and the reserved `_meta` envelope are required 2026 wire fields. The official v2 SDK's codec adds and consumes them: public handler return types and public result types intentionally do not expose `resultType`. Do not manually add `resultType`, construct/read reserved `_meta` keys, or couple application logic to raw wire envelopes; use the documented SDK handler context, result, capability, and version APIs instead.

## Modern Request Handling

- Every modern request carries `_meta` with required protocol version and client capabilities; client info and log level are optional. The SDK owns this envelope. Do not infer metadata from a prior connection.
- `server/discover` is mandatory for servers and advertises supported versions, capabilities, instructions, and cache hints. Server identity is not a `DiscoverResult` body field: it is supplied on every response, including discovery, as `result._meta["io.modelcontextprotocol/serverInfo"]`. In v2 clients, use `client.getServerVersion()` rather than parsing that wire metadata. Clients may call an operation directly, but use discovery for version/capability presentation and compatibility probing.
- `resultType: "complete"` is the final result. `resultType: "input_required"` carries MRTR `inputRequests` and optional opaque `requestState`.
- Treat `requestState` as attacker-controlled when it returns. Bind integrity-protected state to the authenticated principal, original request, and a short expiry; reject failed validation and prevent replay where required.
- Use `subscriptions/listen` for a durable notification stream. Do not rely on legacy `resources/subscribe` semantics for 2026 connections.
- Tasks are an extension capability, not a core feature. Advertise and negotiate the extension before using task methods; do not assume a peer supports them.

## Primitives

- **Tools**: model-controlled actions, mutations, searches, computations, or API calls. Use a stable name, one coherent purpose, explicit input schema, helpful description, and structured output when consumers need it.
- **Resources**: read-only application-controlled context. Use fixed URIs or templates, include MIME type, and return resource links instead of oversized tool content when appropriate.
- **Prompts**: user-controlled reusable interaction templates.

## Client Features And Deprecations

Sampling, Roots, and Logging remain specified but are deprecated as of `2026-07-28`; do not choose them for new design. Prefer direct model-provider integration, explicit tool/resource parameters or configuration, stderr/OpenTelemetry respectively. Existing implementations may retain them while migrating.

MRTR replaces direct server-initiated Sampling, Elicitation, and Roots requests on modern wire. Never request secrets with form elicitation; use URL/out-of-band authorization flows. Roots remain coordination hints, never an access-control boundary.

## Errors, Caching, And Security

- A business failure after a tool ran is a tool result with `isError: true`. Invalid methods/params, unsupported capabilities, malformed JSON-RPC, and internal protocol failures are protocol errors. Clients handle both `isError` and thrown errors.
- Modern cacheable results use `ttlMs` and `cacheScope` (`public` or `private`), rather than treating HTTP cache headers as a substitute for MCP semantics. Never reuse `private` data across authorization contexts.
- On HTTP, align the required `MCP-Protocol-Version` header with `_meta`; use the specification's authorization/`WWW-Authenticate` and insufficient-scope flow. Do not treat `401`/`403` as protocol-era evidence.
- Do not use credentials to fetch server-provided icons. Validate tool inputs and resource URIs server-side, use least privilege, and authenticate/authorize remote servers.
- Use Host validation or framework DNS-rebinding protection for local HTTP servers. Keep stdio stdout exclusively for protocol messages and log to stderr.

## Transport Selection

- Use **stdio** for a local process spawned by the host.
- Use **Streamable HTTP** for remote, browser-accessible, or multi-client operation.
- Use legacy **HTTP+SSE** only to maintain an existing peer; it is deprecated.
- Select and confirm the server-side HTTP framework before implementation. Then verify CORS, Host handling, authorization, shutdown, and the selected era's behavior.
