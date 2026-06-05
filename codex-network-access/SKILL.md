---
name: codex-network-access
description: Use when the user asks to allow Codex sandbox network access, permit requests to a specific domain, add a domain to the Codex CLI network allowlist, or configure ~/.codex/config.toml network_proxy domains.
---

# Codex Network Access

When asked to allow network access for Codex sandboxed commands, update `~/.codex/config.toml`.

Keep access narrow:

- Enable sandbox network access with `[sandbox_workspace_write] network_access = true`.
- Enable `[features.network_proxy] enabled = true`.
- Add only the requested domain to `features.network_proxy.domains` as an `allow` rule.
- Preserve existing allowed or denied domains; merge new entries instead of replacing the table.
- Validate the TOML after editing, for example with `python3 -c 'import tomllib; tomllib.load(open("/Users/maguroid/.codex/config.toml", "rb"))'`.

Example:

```toml
[sandbox_workspace_write]
network_access = true

[features.network_proxy]
enabled = true
domains = { "api.x.com" = "allow" }
```
