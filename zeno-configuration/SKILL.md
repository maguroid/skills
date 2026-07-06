---
name: zeno-configuration
description: Configure and verify Zeno snippets for this user's zsh environment. Use when Codex needs to add, update, explain, or debug zeno.zsh snippet expansion, keyword mappings such as gsw to git switch, Zeno config files, or Zeno key bindings in this environment.
---

# Zeno Configuration

## Locations

Zeno is installed as a Zim module:

- Module declaration: `$HOME/.zsh.d/.zimrc`
- Installed module: `$HOME/.zsh.d/.zim/modules/zeno.zsh`
- Runtime executable: `$HOME/.zsh.d/.zim/modules/zeno.zsh/bin/zeno`
- Live config: `$HOME/.config/zeno/config.yml`
- History database: `$HOME/.local/share/zeno/history.db`
- Key binding hook: `$HOME/.zsh.d/hooks/tools/zeno.zsh` (chezmoi-managed)

`$HOME/.zsh.d/hooks/tools/zeno.zsh` binds Space to `zeno-auto-snippet`, Tab to `zeno-completion`, and `^Xx` to `zeno-insert-snippet` when `ZENO_LOADED` is set. It sets key bindings only; the Zim module loads zeno itself.

The Zim module is the single install. A legacy clone at `$HOME/.local/share/zeno.zsh` was removed on 2026-07-06; if a shell reports `zeno-bootstrap.zsh: missing required directory`, check for a stale `ZENO_ROOT` in the environment (e.g. a long-running tmux server's global environment) — the bootstrap honors a pre-set `ZENO_ROOT` over its own location.

## Editing Workflow

For persistent config changes:

1. Inspect the live config:

```sh
sed -n '1,220p' "$HOME/.config/zeno/config.yml"
```

2. Edit `$HOME/.config/zeno/config.yml`.
3. Preserve YAML structure and existing snippets.
4. Tell the user to run `exec zsh` or open a new shell if an existing terminal does not pick up the change.

## Snippet Format

Use the existing `snippets:` list in `config.yml`.

Example:

```yaml
snippets:
  - name: git switch
    keyword: gsw
    snippet: git switch {{branch}}
```

For a simple static expansion, omit placeholders:

```yaml
  - name: git status
    keyword: gs
    snippet: git status --short --branch
```

For evaluated snippets, use `evaluate: true` and a context guard:

```yaml
  - name: current branch
    keyword: B
    snippet: git symbolic-ref --short HEAD
    context:
      lbuffer: '^git\s+(switch|checkout)\s+'
    evaluate: true
```

## Verification

Use interactive zsh for verification:

```sh
zsh -ic 'print -r -- ZENO_LOADED=$ZENO_LOADED'
zsh -ic 'whence -a zeno'
zsh -ic "zeno --zeno-mode=auto-snippet --input.lbuffer='gsw' --input.rbuffer=''"
```

Expected auto-snippet output starts with `success`, followed by the expanded command and cursor position.

Do not use `zeno auto-snippet ...` in this environment; this Zeno build expects the `--zeno-mode=auto-snippet` form.

## Known Working Example

`gsw` to `git switch` is represented as:

```yaml
  - name: git switch
    keyword: gsw
    snippet: git switch {{branch}}
```

When Space triggers `zeno-auto-snippet`, `gsw` expands to `git switch ` and leaves the cursor after the trailing space.
