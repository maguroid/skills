---
name: pi-sdk
description: "Build, embed, automate, or troubleshoot Pi agents, the Pi CLI, and @earendil-works/pi-* (formerly @mariozechner/pi-*) SDKs and authentication."
---

# Pi SDK

Build or automate Pi using the installed version's API. The bundled examples record July 2026 behavior;
check installed types and [current documentation](https://pi.dev/docs/latest) before relying on version-sensitive names or auth behavior.

The recorded repository is `earendil-works/pi`, formerly `badlogic/pi-mono`.
Its packages use `@earendil-works/pi-*`; older examples use `@mariozechner/pi-*`.
Resolve package compatibility before migrating an existing project.

## Read for the requested task

- SDK integration, layer choice, custom tools, or structured extraction: [sdk.md](references/sdk.md).
- OAuth, subscription billing, auth persistence, or refresh: [auth.md](references/auth.md).
- JSON/RPC mode, cron, or containers: [headless.md](references/headless.md).
- Runtime failures, concurrent auth access, or compatibility limitations: [troubleshooting.md](references/troubleshooting.md).

Pi tools run with the host process's privileges; do not assume an internal sandbox.
For untrusted extraction inputs, use no tools and validate the output schema.
Choose `pi-ai` for LLM calls, `pi-agent-core` for a custom tool loop, and `pi-coding-agent`
when its session, coding tools, or persisted authentication are useful.
Preserve the project's package manager and version constraints. Verify the affected integration rather than rebuilding unrelated layers.
