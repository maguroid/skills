---
name: chezmoi-workflow
description: Manage dotfiles with chezmoi only when the user explicitly asks to manage, add, update, edit, remove, diff, or apply files through chezmoi. Use for requests that clearly mention chezmoi or ask to update chezmoi-managed dotfiles, including adding unmanaged files to the source state, editing existing chezmoi templates or dotfiles, removing managed files, previewing changes with chezmoi diff, and applying approved changes with chezmoi apply. Do not use for ordinary dotfile or shell configuration edits unless the user explicitly requests chezmoi management.
---

# Chezmoi Workflow

## Overview

Use chezmoi as the source of truth for dotfile changes, and keep a clear boundary between source-state edits and applying changes to the target home directory. Trigger this workflow only for explicit chezmoi requests; otherwise treat dotfiles like normal repository files.

## Core Rules

- Confirm the active directory is the chezmoi source repo, or locate it with `chezmoi source-path`.
- Inspect repository state before editing: `git status --short --branch` in the source repo and `chezmoi diff` when target-state impact matters.
- Never overwrite unrelated dirty changes in the source repo or target files. Work with them or ask if they block the requested change.
- Prefer editing the chezmoi source file directly. Use `chezmoi add` only when importing target files into source state.
- Treat `chezmoi apply` as a real write to the user's home directory. Run it only when the user asked for apply/update or after showing the diff for the requested operation.
- When a file is templated, preserve chezmoi template syntax and verify rendered output through `chezmoi diff`, not by guessing.

## Orientation

1. Find the source repo:

```sh
chezmoi source-path
git -C "$(chezmoi source-path)" status --short --branch
```

2. Map target paths to source paths when needed:

```sh
chezmoi source-path ~/.zshrc
chezmoi managed
chezmoi status
```

3. Preview rendered target changes before applying:

```sh
chezmoi diff
```

Use narrower commands when the request is scoped to one path:

```sh
chezmoi diff ~/.zshrc
chezmoi apply --dry-run --verbose ~/.zshrc
```

## Add A New Managed File

Use this when the user asks to start managing an existing target file with chezmoi.

1. Inspect the target file if needed.
2. Import it:

```sh
chezmoi add ~/.config/example/config.toml
```

3. Inspect the created source file in `chezmoi source-path`.
4. Edit the source file if the requested change should be included immediately.
5. Run `chezmoi diff` and report the exact target impact.

For a brand-new dotfile that does not exist in the target home directory, create the appropriate source file under the chezmoi source repo. Use chezmoi naming conventions such as `dot_zshrc`, `private_`, `executable_`, `readonly_`, and `.tmpl` when needed, then verify with `chezmoi diff`.

## Edit An Existing Managed File

1. Locate the source file:

```sh
chezmoi source-path ~/.zshrc
```

2. Read surrounding content and existing patterns before editing.
3. Edit the source file, not the rendered target file, unless the user specifically asks for a target-only change.
4. If the source is a template, keep conditionals and data references intact. Use `chezmoi execute-template` or `chezmoi diff` to check rendered behavior.
5. Run `chezmoi diff` for the touched path or whole repo, depending on scope.

## Remove A Managed File

Use this when the user explicitly asks to stop managing or delete a chezmoi-managed file.

1. Determine whether the user wants to remove only chezmoi management or also remove the target file from the home directory.
2. For source-only removal, delete the source file from the chezmoi repo and preview with `chezmoi diff`.
3. For target removal through chezmoi, use chezmoi's remove workflow when appropriate:

```sh
chezmoi remove ~/.config/example/config.toml
```

4. Inspect the source repo diff and `chezmoi diff` before finalizing.
5. Do not run destructive target changes without a clear user request.

## Apply Changes

Apply only after the diff has been inspected and the user asked for changes to be applied, or when the original request explicitly included applying/updating the machine through chezmoi.

```sh
chezmoi diff
chezmoi apply
```

For scoped changes:

```sh
chezmoi diff ~/.zshrc
chezmoi apply ~/.zshrc
```

After applying, run a quick verification:

```sh
chezmoi status
git -C "$(chezmoi source-path)" status --short
```

## Report Back

Summarize:

- Source files changed in the chezmoi repo.
- Whether `chezmoi diff` was clean, pending, or applied.
- Whether `chezmoi apply` was run.
- Any unrelated dirty state that was present before or remains after the work.
