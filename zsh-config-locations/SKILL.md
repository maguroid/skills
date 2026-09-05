---
name: zsh-config-locations
description: "Locate, explain, or edit this user’s zsh configuration under ~/.zsh.d."
---

# Zsh Config Locations

## Core Fact

This environment has moved zsh configuration into `$HOME/.zsh.d`.

- `$HOME/.zshenv` is still at the home directory root.
- `$HOME/.zshenv` sets `ZDOTDIR="$HOME/.zsh.d"`.
- Because of `ZDOTDIR`, zsh reads files such as `.zshrc`, `.zprofile`, and `.zimrc` from `$HOME/.zsh.d`.
- Do not assume `$HOME/.zshrc` exists or is the right edit target.

## Runtime Layout

- `$HOME/.zsh.d/.zshrc`: main interactive zsh config.
- `$HOME/.zsh.d/.zprofile`: login-shell setup.
- `$HOME/.zsh.d/.zimrc`: Zim module list and plugin declarations.
- `$HOME/.zsh.d/hooks/`: modular files sourced by `.zshrc`.
- `$HOME/.zsh.d/hooks/alias.zsh`: aliases.
- `$HOME/.zsh.d/hooks/tools/`: tool initialization snippets such as Zim, mise, starship, direnv, pnpm, and cloud CLIs.
- `$HOME/.zsh.d/hooks/functions/`: custom shell functions.
- `$HOME/.zsh.d/hooks/bindings/`: key bindings such as Zeno bindings.
- `$HOME/.zsh.d/site-functions/`: completion functions added to `fpath`.
- `$HOME/.zsh.d/docs/`: notes about the shell setup.
