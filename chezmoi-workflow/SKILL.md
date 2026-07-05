---
name: chezmoi-workflow
description: Keep chezmoi-managed dotfiles synced with the source repo, treating chezmoi as the default path for dotfile work rather than an opt-in. Use for (1) any task that edits or appends to configuration under a chezmoi-managed location (e.g. ~/.zsh.d, ~/.config/nvim, ~/.claude, ~/.codex, ~/.config/ghostty) even when chezmoi isn't named and even when no specific file is named — "zshにエイリアス追加して", "add a zsh alias", "change the ghostty config", "update the nvim keymap" — first check whether the target is chezmoi-managed and if so follow this workflow; (2) requests to sync or reconcile local drift into chezmoi, e.g. "dotfiles同期して", "sync dotfiles", "chezmoiに取り込んで", "pull my local changes into chezmoi"; (3) explicit chezmoi operations such as add, edit, remove, diff, apply. Do not use for files that are not part of the chezmoi source state (verify with `chezmoi source-path`) unless the user explicitly asks to bring them under chezmoi management. Pulling remote changes down to this machine (`chezmoi update` / `chezmoi init`) is out of scope — that is the `harness-sync` skill's job.
---

# Chezmoi Workflow

## Overview / Mental Model

- The source repo (`~/.local/share/chezmoi`, remote `github.com:maguroid/dotfiles`, branch `main`) is the single source of truth. Treat it, not $HOME, as canonical.
- `~/.config/chezmoi/chezmoi.toml` sets `[git] autoCommit = true` and `autoPush = true`. **chezmoi commands that modify the source state** (`chezmoi add`, `chezmoi re-add`, `chezmoi edit`, `chezmoi forget`, `chezmoi remove`, …) commit and push to the remote automatically. Directly editing a source file with an editor or Write/Edit tools does **not** trigger this — such changes need a manual commit and push.
- Because a chezmoi command pushes the moment it runs, secret review must happen **before** the source state changes, not after.
- lefthook + secretlint run at **pre-push** (not pre-commit). A rejected push still leaves the offending commit sitting locally on `main` — see Recovery below.
- The managed set is large, spanning `~/.zsh.d`, `~/.config/nvim`, `~/.claude`, `~/.codex`, and more. Repo-only tooling at the source root is excluded via `.chezmoiignore` and is not distributed to $HOME.

## Detect Management

Before editing any dotfile-like path, check whether it's actually under chezmoi. The authoritative test:

```sh
chezmoi source-path ~/.config/ghostty/config   # succeeds only if managed
```

(`chezmoi managed` can help browse or search the managed set when exploring.)

- Managed → follow the Edit Flow below.
- Not managed → treat it as an ordinary file edit. Only bring it under chezmoi management if the user explicitly asks (see Add/Remove); don't add new files proactively.

## Edit Flow

Use whenever a task changes settings that happen to live under chezmoi, whether or not chezmoi is mentioned by name.

1. Locate the source file: `chezmoi source-path <target>`.
2. **Secret review (before any source write)**: confirm the content you're about to add contains no API keys, tokens, passwords, private keys, or internal hostnames. Optionally run the repo's linter early: `cd "$(chezmoi source-path)" && npx secretlint <path>` — catching a secret here avoids history repair later.
3. Edit the source file directly (not the rendered target) unless the user specifically wants a target-only experiment.
4. Preview: `chezmoi diff` (or scoped: `chezmoi diff <target>`). This validates the rendered result; it is **not** a secret gate — that already happened in step 2.
5. Apply: `chezmoi apply <target>` (or whole tree). Treat apply as a real write to $HOME.
6. Publish. Direct source edits are not auto-committed, so run:

   ```sh
   git -C "$(chezmoi source-path)" add <source-file>
   git -C "$(chezmoi source-path)" commit -m "..."
   git -C "$(chezmoi source-path)" push   # secretlint runs here (pre-push)
   ```

   If the source was changed via a chezmoi command instead, autoCommit + autoPush already ran — skip this and just verify the push.
7. If the target was edited first (e.g. a quick local test), confirm it works, run the secret review on the resulting content, then reconcile with `chezmoi re-add <target>` (auto-commits and pushes). Note `re-add` will not overwrite `.tmpl` source files, so template edits must go directly into the source.
8. Templates: preserve `{{ }}` syntax; verify rendered output with `chezmoi diff` or `chezmoi execute-template` rather than guessing.

## Sync Flow (drift reconciliation)

This is the core scenario: $HOME has drifted from the chezmoi source (manual edits, tool-managed config, etc.) and needs to be folded back in.

1. Enumerate drift: `chezmoi status`.
2. For each drifted target, inspect the change: `chezmoi diff <target>`.
3. **Secret review** (mandatory, before touching source state): scan the diff by eye for API keys, tokens, passwords, private keys, internal hostnames, and similar values. Optionally also run `npx secretlint` from the source repo on the affected paths.
4. If clean, fold it in: `chezmoi re-add <target>` — this commits and pushes automatically.
5. If it contains secrets, do not re-add. Propose templating the file instead (see Secrets Handling) so the secret is externalized before it's folded in.
6. After processing all drifted files, re-run `chezmoi status` to confirm nothing is left, and confirm the push actually succeeded (see Report Back).

## Secrets Handling

- Convert files that carry secrets into `.tmpl` sources; inject the real value at apply time — never hardcode it in the source tree.
- Injection sources: an environment variable, a password manager, or `chezmoi data` (the `[data]` table in `chezmoi.toml`). Before putting a secret in `[data]`, verify that `~/.config/chezmoi/chezmoi.toml` itself is neither chezmoi-managed nor git-tracked — otherwise the secret only moves, it doesn't hide. Secrets belong only in local untracked files, env vars, or a password manager.
- `private_` only tightens file permissions on the rendered target (e.g. `0600`); it does **not** stop the content from being committed and pushed to the remote. Don't rely on it for confidentiality.
- Once a file is templated, `chezmoi re-add` will not clobber it, so templating is the durable fix for recurring drift that would otherwise leak secrets.

## Recovery When secretlint Blocks a Push

Because the hook runs at pre-push, a blocked push still leaves the secret committed locally. Until history is repaired, **do not run any source-mutating chezmoi command** — autoCommit would stack new commits on top of the tainted one.

1. Remove or templatize the secret by editing the source file manually (not via chezmoi); confirm with `git -C "$(chezmoi source-path)" diff`.
2. Repair history in `$(chezmoi source-path)`:
   - Tip commit only: `git commit --amend`.
   - Multiple commits: `git reset --soft <commit-before-the-secret>`, then recommit cleanly.
3. Verify: check `git log` for the secret and optionally re-run `npx secretlint` on the affected paths.
4. Push explicitly: `git -C "$(chezmoi source-path)" push`. The earlier push was blocked, so the remote was never tainted — a normal push suffices, no force push needed.
5. Only if the secret actually reached the remote (e.g. the hook was bypassed): treat it as compromised and rotate/revoke it. Rewriting history is not sufficient once a secret has left the local machine.

## Add / Remove Managed Files

- Add a new file to chezmoi management **only on explicit request**. Run the secret review on its contents before `chezmoi add`, since add triggers autoCommit/autoPush immediately.
- For a brand-new dotfile with no existing target, create the source file directly using chezmoi naming conventions (`dot_zshrc`, `private_`, `executable_`, `.tmpl`), verify with `chezmoi diff`, then commit and push manually — direct creation does not auto-commit.
- Removal — decide, preview, execute, verify:
  1. Confirm with the user: stop tracking only (keep the target in $HOME), or also delete the target?
  2. Preview the impact where possible (`chezmoi diff`, inspect the source file).
  3. Execute: `chezmoi forget <target>` for source-only removal, or `chezmoi remove <target>` to also delete the target from $HOME (both auto-commit/push).
  4. Verify with `chezmoi status` and `git -C "$(chezmoi source-path)" log -1 --oneline`.

## Report Back

Summarize:

- Which source files changed, and how they were published — autoCommit/autoPush (which chezmoi command) or manual commit/push — with the resulting commit hash (`git -C "$(chezmoi source-path)" log -1 --oneline`).
- Result of the secret review (clean / templated / rotation needed).
- Whether the push actually succeeded, or is stuck behind secretlint (and what recovery step is still pending).
- Any remaining drift (`chezmoi status` non-empty) or unrelated dirty state left untouched.
