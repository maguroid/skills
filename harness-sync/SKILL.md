---
name: harness-sync
description: Bootstrap a new machine or Mac onto this user's agent working environment (dotfiles, mise tools, global skills, credentials) and diagnose whether an existing machine is fully synced. Use for (1) "新しい Mac をセットアップして" / "別端末に環境を同期して" / "環境を同期して" / setting up a new terminal or machine for agent work; (2) "ハーネス同期" / checking whether this machine has everything the harness needs; (3) "セットアップ状況を診断して" / running or interpreting the environment doctor script; (4) pulling remote changes down to this machine — `chezmoi update` / `chezmoi init --apply` — including any run_onchange follow-through (mise install, skill bootstrap). Do NOT use for pushing local dotfile edits or drift back into chezmoi source (that is the `chezmoi-workflow` skill's job), for authoring or migrating individual skills (that is `global-skill-workflow`'s job), or for agent memory sync (that is `feedback-assetization`'s job) — this skill only points to those.
---

# Harness Sync

Helps an agent set up a brand-new machine, or check/refresh an existing one, so it has
everything needed to do agent work: dotfiles, CLI tools, global skills, and (where
possible) credentials. This is the **pull-direction** counterpart to `chezmoi-workflow`
(which owns push-direction edits and drift reconciliation).

## Mental Model

Four things sync independently, by four different mechanisms. Nothing here needs to be
invented — these are already wired up:

| What | Source of truth | Sync mechanism |
|---|---|---|
| Dotfiles (`~/.zsh.d`, `~/.claude/{CLAUDE.md,settings.json,keybindings.json}`, `~/.codex/{config.toml,AGENTS.md,rules}`, `~/.config/mise`, ...) | `git@github.com:maguroid/dotfiles.git` (branch `main`), local checkout `~/.local/share/chezmoi` | chezmoi (`chezmoi init --apply` first time, `chezmoi update` thereafter) |
| Runtime/CLI tools (node, uv, etc.) | `~/.config/mise/config.toml` (itself chezmoi-managed) | mise (`mise install`, triggered automatically by a chezmoi run_onchange hook whenever the config changes) |
| Global skills (`chezmoi-workflow`, `global-skill-workflow`, `feedback-assetization`, this skill, ...) | `maguroid/skills` (agent-neutral) + `maguroid/cc-skills` (Claude Code-only) + any private repos in `~/.agents/skills-repos.local.md` | clone + `bootstrap.sh` (symlinks into `~/.agents/skills` and `~/.claude/skills`), triggered automatically by a chezmoi run_onchange hook whenever the skill registry changes |
| Agent memory (project/user knowledge, briefs, GC) | hub repo (e.g. Workspace-Me) `agent-memory/` | plain git clone/pull of the hub repo — out of scope here, see `feedback-assetization` |

Credentials and machine-specific state are **not** distributed by any of the above and
must be established per machine: `~/.llmx/credentials`, `~/.config/gogcli/credentials.json`,
`~/.claude/.credentials.json`, `~/.codex/auth.json`, SSH keys, and the Orca app + its hook
at `~/.orca/agent-hooks/claude-hook.sh` (Orca app install is a manual prerequisite).

## New Machine Setup

Prerequisites: Xcode Command Line Tools (for `git`), and an SSH key registered with
GitHub (`gh auth login` then `gh ssh-key add`, or manual key setup).

1. Run the bootstrap one-liner:

   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:maguroid/dotfiles.git
   ```

2. This chains automatically, in order:
   - `run_once_before_00-install-mise.sh` installs mise if it isn't present yet.
   - chezmoi applies the full dotfile set into `$HOME` (`~/.zsh.d`, `~/.claude`, `~/.codex`,
     `~/.config/mise`, etc.).
   - `run_onchange_after_10-mise-install.sh` runs `mise install` to pull every tool
     declared in `~/.config/mise/config.toml`.
   - `run_onchange_after_20-bootstrap-global-skills.sh` clones `maguroid/skills` (and any
     registry repos) and runs `bootstrap.sh`, wiring up `~/.agents/skills/*` and
     `~/.claude/skills/*` symlinks. See `global-skill-workflow` for what this script does
     in detail — don't re-explain it here.

3. Run the diagnostic script and interpret its output for the user:

   ```sh
   bash ~/.local/share/chezmoi/scripts/doctor.sh
   ```

   It always exits 0 (even with MISSING items) and prints a summary count at the end —
   treat a nonzero MISSING count as a checklist, not a failure. It checks: auth files
   (`~/.llmx/credentials`, `~/.config/gogcli/credentials.json`, `~/.claude/.credentials.json`,
   `~/.codex/auth.json`), SSH keys, the Orca hook file, any real (non-symlink) directory
   under `~/.agents/skills` that isn't backed by a canonical repo, and `mise doctor`.

4. Walk the user through each MISSING item — see "Handling doctor Gaps" below. Do not
   treat the run as complete until doctor is clean or the user has explicitly accepted
   remaining gaps (e.g. no Orca on this machine).

## Handling doctor Gaps

None of these can be done by the agent alone — each needs an interactive login or a
manual transfer. For each MISSING item, tell the user what command to run and why:

- `~/.claude/.credentials.json` missing → have the user run `claude` and log in
  interactively (`! claude` from the agent, or a separate terminal).
- `~/.codex/auth.json` missing → have the user run `codex login`.
- `~/.llmx/credentials` or `~/.config/gogcli/credentials.json` missing → these are
  typically copied from an existing machine (they're not re-derivable by login flow);
  ask the user whether to copy from another machine or re-run that tool's own setup.
- SSH key missing → `gh auth login` + `gh ssh-key add`, or manual `ssh-keygen` +
  registering the public key on GitHub.
- Orca hook missing → confirm whether the user actually wants Orca on this machine; if
  yes, installing the Orca app is the prerequisite, the hook file follows from that.
- A real (non-symlinked) directory under `~/.agents/skills` → this is drift, not a sync
  gap; hand off to `global-skill-workflow`'s conflict-handling, don't resolve it here.

## Daily Sync (existing machine)

```sh
chezmoi update
```

This pulls the dotfiles repo and re-applies. Any change to `~/.config/mise/config.toml`
or the skill registry (`~/.agents/skills-repos.local.md`) is picked up automatically by
the same run_onchange hooks as in New Machine Setup — no separate mise or skill-bootstrap
step is needed. Run `bash ~/.local/share/chezmoi/scripts/doctor.sh` afterward if there's
any doubt about credential or hook state (e.g. after a long gap since last sync, or before
relying on a tool that needs auth).

## Agent Behavior

- Run the commands above directly (curl one-liner, `chezmoi update`, `doctor.sh`) rather
  than just describing them.
- Read and interpret doctor's output for the user; don't just paste it raw. Group
  findings into "nothing to do", "needs a login command", and "needs manual transfer".
- Never attempt interactive logins (`claude`, `codex login`, `gh auth login`) on the
  user's behalf — these require a real terminal/browser interaction. Tell the user the
  exact command to run themselves.
- If doctor reports skill-registry drift or a skill conflict, hand off to
  `global-skill-workflow` rather than resolving symlinks here.

## Out of Scope (see these skills instead)

- **Push direction**: editing dotfiles, folding local drift back into chezmoi source,
  secret handling in dotfiles → `chezmoi-workflow`.
- **Skill authoring/sync details**: creating a new skill, updating an existing one,
  migrating between repos, the exact symlink reconciliation algorithm → `global-skill-workflow`.
- **Agent memory**: hub `agent-memory/` sync, GC, brief extraction → `feedback-assetization`.

Do not duplicate those skills' procedures here; link out to them instead.
