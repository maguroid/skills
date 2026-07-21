# Codex CLI standalone installation

Use OpenAI's standalone installer on every Mac; do not declare `codex` in
`$HOME/.config/mise/config.toml`. This exception preserves the official installation and
update path while the rest of the general CLI toolchain remains mise-managed.

## Install or update

Run the same installer for both first installation and updates:

```sh
curl -fsSL https://chatgpt.com/codex/install.sh | sh
hash -r
type -a codex
codex --version
```

The installer normally exposes `$HOME/.local/bin/codex`. The ChatGPT desktop app may
also bundle a `codex` binary. Inspect `type -a codex` and ensure an ordinary terminal
resolves the standalone binary when CLI use must not depend on the app. Open a fresh
shell if the current shell retains an earlier command path.

## Per-machine state

The standalone CLI continues to use `~/.codex` configuration, but authentication stays
machine-local. Run `codex login` interactively on each Mac when needed. Never copy
`~/.codex/auth.json` from another machine.
