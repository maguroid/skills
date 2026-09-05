---
name: codex-network-access
description: "Configure Codex sandbox network access or domain allowlists when the user requests network permission changes."
---

# Codex Network Access

When asked to allow network access for Codex sandboxed commands, update `~/.codex/config.toml`.

Keep access narrow:

- Enable sandbox network access with `[sandbox_workspace_write] network_access = true`.
- Enable `[features.network_proxy] enabled = true`.
- Add only the requested domain to `features.network_proxy.domains` as an `allow` rule.
- Preserve existing allowed or denied domains; merge new entries instead of replacing the table.
- Validate the TOML after editing, for example with `python3 -c 'import pathlib, tomllib; tomllib.load(open(pathlib.Path.home() / ".codex/config.toml", "rb"))'`.

Example:

```toml
[sandbox_workspace_write]
network_access = true

[features.network_proxy]
enabled = true
domains = { "api.x.com" = "allow" }
```
