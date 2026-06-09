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
- Chezmoi source, when present: `$HOME/.local/share/chezmoi/dot_config/zeno/config.yml`
- History database: `$HOME/.local/share/zeno/history.db`
- Key binding hook: `$HOME/.zsh.d/hooks/bindings/zeno.zsh`

`$HOME/.zsh.d/hooks/bindings/zeno.zsh` binds Space to `zeno-auto-snippet` when `ZENO_LOADED` is set.

## Editing Workflow

For persistent config changes:

1. Inspect the live config and chezmoi source:

```sh
sed -n '1,220p' "$HOME/.config/zeno/config.yml"
sed -n '1,220p' "$HOME/.local/share/chezmoi/dot_config/zeno/config.yml"
git -C "$HOME/.local/share/chezmoi" status --short
```

2. Edit both files if the chezmoi source exists. If the source file is absent, create or update it under `$HOME/.local/share/chezmoi/dot_config/zeno/config.yml` and keep it in sync with the live config.
3. Preserve YAML structure and existing snippets.
4. Do not revert unrelated chezmoi changes.
5. Tell the user to run `exec zsh` or open a new shell if an existing terminal does not pick up the change.

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
