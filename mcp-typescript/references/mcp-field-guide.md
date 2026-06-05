# MCP Field Guide

## Contract

MCP is a JSON-RPC 2.0 protocol for standardized context exchange between an AI host application and external programs. A host creates one MCP client per connected server. Each client maintains a direct connection to its server.

MCP has two layers:

- Data layer: lifecycle, capability negotiation, requests, responses, notifications, and primitives.
- Transport layer: stdio for local process-spawned servers and Streamable HTTP for network or multi-client servers.

An implementation must respect initialization, negotiated capabilities, method schemas, notifications, pagination, and error surfaces. Do not reduce MCP to an ad hoc REST API or a plain function registry.

## Lifecycle And Capabilities

Connections begin with `initialize`, including protocol version, implementation info, and client capabilities. The server replies with its selected protocol version, implementation info, instructions, and server capabilities. The client then sends `notifications/initialized`.

Rules:

- Do not call capability-dependent methods unless the peer declared support.
- Use server instructions for cross-tool workflow guidance and constraints, not as a duplicate of every tool description.
- Treat the versioned schema in the spec repository as the final contract when docs/examples are ambiguous.

## Server Primitives

Use the smallest primitive that matches the user-facing behavior.

### Tools

Tools are model-controlled executable actions. Use tools for API calls, mutations, searches, computations, and operations the model should decide to invoke.

Good tools:

- Have stable machine-friendly names.
- Have a single coherent purpose.
- Include precise input schemas and helpful field descriptions.
- Return text for the model and `structuredContent` when clients need machine-readable data.
- Annotate destructive/read-only/idempotent behavior when supported by the SDK.

### Resources

Resources are read-only context exposed by URI. Use resources for files, database schemas, records, logs, documents, configuration, and other data the host application chooses to attach.

Use direct resources for fixed URIs and resource templates for parameterized URIs. Include MIME types. Prefer resource links from tools when a result is too large to inline.

### Prompts

Prompts are user-controlled reusable templates. Use prompts for workflows users intentionally invoke, such as review templates, query patterns, or domain-specific procedures.

## Client Primitives

Clients may expose capabilities that let servers build richer interactions.

### Sampling

Sampling lets a server request an LLM completion from the client. Use it when a server needs model assistance but should stay model-independent. Clients should keep user oversight and apply their own model/security policy.

### Elicitation

Elicitation lets a server ask the user for structured input while handling a request. Form elicitation must not request secrets. Use URL or out-of-band flows for API keys, passwords, payment data, OAuth, and similarly sensitive data.

### Roots

Roots tell a server which filesystem directories are relevant. They are coordination hints, not a security boundary. Enforce access with OS permissions, sandboxing, allow-lists, and server-side checks.

### Logging

Logging lets servers send structured diagnostic notifications to clients. Use it for observable progress and debug information, not for sensitive data.

## Error Model

Distinguish tool-level and protocol-level errors.

- Tool-level error: the tool executed but the requested business operation failed. Return a tool result with `isError: true` so the model can observe and recover.
- Protocol-level error: invalid method, invalid params, unsupported capability, malformed JSON-RPC, timeout, or internal protocol failure. Let the SDK produce or throw its protocol error type, such as `McpError`, as appropriate.

Clients must check both `result.isError` and thrown errors.

## Security Baseline

- Document server capabilities and required permissions.
- Validate all tool inputs and resource URIs server-side.
- Use least privilege for files, environment variables, credentials, and network access.
- Treat local servers as code running with the user's local permissions.
- For local Streamable HTTP servers, protect against DNS rebinding with Host header validation or framework helpers that provide it.
- Do not write diagnostics or logs to stdout for stdio servers; stdout is the protocol stream. Use stderr for process logs.
- For remote servers, implement appropriate authentication and authorization. Prefer standard OAuth flows when required.

## Transport Selection

- Use stdio for local single-client integrations launched by a host or CLI.
- Use Streamable HTTP for remote servers, browser-accessible clients, or multi-client servers.
- Use stateful Streamable HTTP when sessions, resumability, server-initiated streaming, or per-session state is needed.
- Use stateless Streamable HTTP only when each request can be handled independently.
- Use legacy SSE only for compatibility with older servers.
