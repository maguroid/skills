---
name: harness-sync
description: >-
  Sync this user's agent environment across machines in both directions: pull/bootstrap from remotes and push chezmoi-managed local changes back to the source repo. Use for new Mac setup, environment or harness sync, setup diagnosis and doctor output, `chezmoi update` / `chezmoi init --apply`, hook-driven mise/skill/hub sync, pull conflicts, and explicit chezmoi add/edit/remove/diff/apply operations. Also use for edits under locations such as `~/.zsh.d`, `~/.config/nvim`, `~/.claude`, `~/.codex`, or `~/.config/ghostty`: first check `chezmoi source-path`, then follow this workflow when managed. Use for "dotfiles同期して", "chezmoiに取り込んで", or reconciling local drift. Do not use for unmanaged files unless the user asks to manage them, for individual skill authoring or migration (`global-skill-workflow`), or for agent-memory GC, briefs, and conventions (`feedback-assetization`); cloning and pulling hub repos that carry memory remains covered.
---

# Harness Sync

One skill for both directions of environment sync. **Pull**: set up a brand-new machine,
or refresh an existing one, from the canonical remotes (dotfiles, CLI tools, global
skills, hub repos, and — where possible — credentials). **Push**: edit chezmoi-managed
dotfiles and fold local drift back into the chezmoi source repo, with secret hygiene.

## Mental Model

Four things sync independently, by four different mechanisms. Nothing here needs to be
invented — these are already wired up:

| What | Source of truth | Sync mechanism |
|---|---|---|
| Dotfiles (`~/.zsh.d`, `~/.claude/{CLAUDE.md,settings.json,keybindings.json}`, `~/.codex/{config.toml,AGENTS.md,rules}`, `~/.config/mise`, ...) | `git@github.com:maguroid/dotfiles.git` (branch `main`), local checkout `~/.local/share/chezmoi` | chezmoi (`chezmoi init --apply` first time, `chezmoi update` thereafter) |
| Runtime/CLI tools (node, uv, etc.) | `~/.config/mise/config.toml` (itself chezmoi-managed) | mise (`mise install`, triggered automatically by a chezmoi run_onchange hook whenever the config changes) |
| Rust toolchain (`rustup`, `rustc`, `cargo`) | rustup stable channel; bootstrap logic in the chezmoi source | rustup (`run_before_05-install-rustup.sh`; shell PATH remains chezmoi-managed) |
| Global and registered skill repos (`global-skill-workflow`, `feedback-assetization`, this skill, ...) | `maguroid/skills` (agent-neutral) + `maguroid/cc-skills` (Claude Code-only) + `maguroid/codex-skills` (Codex-only) + any private repos in `~/.agents/skills-repos.local.md` | pull: clone + pull + `bootstrap.sh` (pulls clean registered repos `--ff-only`, then symlinks into home-global discovery directories according to scope; `workspace-only` entries are fetched but not globalized), run on **every** chezmoi apply via a run_after hook (1-hour throttle). push: the three built-in repos auto-commit+push via a global Claude Code Stop hook (`global-skill-workflow/scripts/auto_sync.sh`); registry repos stay manual — see `global-skill-workflow` |
| Workspace-local skills | Each owning workspace repository's `.agents/skills` | `$HOME/.agents/workspace-skills.local.md` maps the owner/organization folder actually opened as the harness root to its canonical workspace skills. After hub sync, the `global-skill-workflow` reconciler projects links into that root's `.agents/skills` and `.claude/skills`; it never globalizes them. |
| Hub repos, incl. agent memory (each hub — e.g. Workspace-Me, Workspace-Foo — carries its `agent-memory/`) | hub registry `~/.agents/hubs.md` (chezmoi-managed; `- 自動同期: true` enables global Stop auto-push) | path migration runs before hub sync; then missing repos are cloned and clean repos pulled. The global Stop hook commits/pushes every dirty or ahead auto-sync hub, independent of cwd; the private hook may also add narrowly scoped companion repositories such as a team wiki. Memory *operation* stays with `feedback-assetization` |

Credentials and machine-specific state are **not** distributed by any of the above and
must be established per machine: `~/.llmx/credentials`, `~/.config/gogcli/credentials.json`,
`~/.claude/.credentials.json`, `~/.codex/auth.json`, per-device xurl OAuth state in
`~/.xurl`, SSH keys, and the Orca app + its hook at
`~/.orca/agent-hooks/claude-hook.sh` (Orca app install is a manual prerequisite).

The user's machines form a hub-and-spoke topology: one always-on **main machine** at home
(the canonical push source for dotfiles/hubs) and one or more portable **follower machines**.
The main machine is normally reachable from followers over SSH (a `~/.ssh/config` host
alias; the concrete hostname is machine-local knowledge — see the global CLAUDE.md's
sync section on that machine, or doctor's hints, rather than this public skill). Copy-only
credentials (`~/.llmx/credentials`, `~/.config/gogcli/credentials.json`) are therefore
fetched from the main machine with `scp` rather than "an old machine" in the abstract.
Never copy `~/.xurl` between machines: OAuth2 refresh-token rotation can invalidate
another machine's stored token. Register the app and run `xurl auth oauth2 <username>`
independently on each machine.

Properties of the chezmoi lane that both directions depend on:

- The source repo (`~/.local/share/chezmoi`, remote `github.com:maguroid/dotfiles`,
  branch `main`) is the single source of truth. Treat it, not $HOME, as canonical.
- `~/.config/chezmoi/chezmoi.toml` sets `[git] autoCommit = true` and `autoPush = true`.
  **chezmoi commands that modify the source state** (`chezmoi add`, `chezmoi re-add`,
  `chezmoi edit`, `chezmoi forget`, `chezmoi remove`, …) commit and push to the remote
  automatically. Directly editing a source file with an editor or Write/Edit tools does
  **not** trigger this — such changes need a manual commit and push.
- Because a chezmoi command pushes the moment it runs, secret review must happen
  **before** the source state changes, not after.
- lefthook + secretlint run at **pre-push** (not pre-commit). A rejected push still
  leaves the offending commit sitting locally on `main` — see Recovery below.
- The managed set is large, spanning `~/.zsh.d`, `~/.config/nvim`, `~/.claude`,
  `~/.codex`, and more. Repo-only tooling at the source root is excluded via
  `.chezmoiignore` and is not distributed to $HOME.

# Pull Direction (this machine ← remotes)

## New Machine Setup

**Existing machine with a stale source?** If chezmoi is already installed but the source
checkout is old, the one-liner below will NOT bring the environment up to date. Telltale
signs: `chezmoi status` works yet today's `scripts/` are missing, or skill links are
fewer than expected / already-deleted skills still present. The right move there is
`chezmoi update -v --force`, then continue at the doctor step.

Prerequisites: Xcode Command Line Tools (for `git`), and an SSH key registered with
GitHub (`gh auth login` then `gh ssh-key add`, or manual key setup).

1. Run the bootstrap one-liner:

   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply git@github.com:maguroid/dotfiles.git
   ```

2. This chains automatically, in order (each stage prints a `==> [1/4]` … `==> [4/4]`
   progress banner):
   - `run_once_before_00-install-mise.sh` installs mise if it isn't present yet.
   - `run_before_05-install-rustup.sh` verifies rustup and the stable Rust toolchain on
     every apply, exits immediately when they are healthy, and installs or repairs them
     only when needed. It uses `--no-modify-path`; chezmoi's zsh configuration is the
     sole owner of Cargo's PATH setup.
   - chezmoi applies the full dotfile set into `$HOME` (`~/.zsh.d`, `~/.claude`, `~/.codex`,
     `~/.config/mise`, etc.).
   - `run_onchange_after_10-mise-install.sh` runs `mise install` to pull every tool
     declared in `~/.config/mise/config.toml` (run_onchange: keyed to the mise config
     hash, so it fires only when that file changes).
   - `run_after_20-bootstrap-global-skills.sh` first pulls the `maguroid/skills` repo
     itself (`git pull --ff-only`, only if clean — so a stale `bootstrap.sh` is never
     used), then clones any missing registry repos and runs `bootstrap.sh`, which pulls
     each clean registered repo and wires up `~/.agents/skills/*` and
     `~/.claude/skills/*` and `~/.codex/skills/*` symlinks. See `global-skill-workflow` for what this script does
     in detail — don't re-explain it here.
   - `run_after_25-migrate-workspace-paths.sh` migrates known legacy Workspace paths to
     ghq before hub sync. A lone legacy repo is moved with dirty state intact. When both
     paths exist, Git history and working-tree state choose the safe winner; redundant
     copies go to `~/.Trash`. Ambiguous states are left untouched with a warning.
   - `run_after_30-sync-hubs.sh` reads the hub registry `~/.agents/hubs.md` and,
     per hub: clones if missing (renaming the remote from `origin` when the entry's
     `- リモート名:` says so — e.g. Workspace-Me uses `github`); if already present and
     clean, runs `git pull --ff-only`; if dirty or diverged, warns and skips. Individual
     hub failures do not fail the apply. Since each hub carries its `agent-memory/`, the
     one-liner covers agent-memory availability too — memory *operation* remains
     `feedback-assetization`'s domain.
     After hub sync, the same hook calls the `global-skill-workflow` workspace reconciler,
     which reads `~/.agents/workspace-skills.local.md` and exposes each workspace's local
     skills from the higher-level owner/organization folder actually used as the harness
     root. This inexpensive reconciliation also runs when the hub pull itself is throttled.
   - `run_after_35-refresh-workspace-remote-control.sh` recreates existing
     `claude-rc-me` / `claude-rc-hsg` tmux sessions only when their start path is a
     migrated legacy Workspace.

   The 20/30 stages are `run_after` hooks: they run on **every** apply, but with a
   1-hour throttle — within an hour of the last successful run they print
   `==> [3/4] スキップ（前回実行から1時間未満。HARNESS_SYNC_FORCE=1 で強制実行）` and skip
   (stamps: `~/.cache/harness-sync/{skills,hubs}-last-run`). Set `HARNESS_SYNC_FORCE=1`
   to force them.

3. Run the diagnostic script and interpret its output for the user:

   ```sh
   bash ~/.local/share/chezmoi/scripts/doctor.sh
   ```

   It always exits 0 (even with MISSING items) and prints a summary count at the end —
   treat a nonzero MISSING count as a checklist, not a failure. It checks: auth files
   (`~/.llmx/credentials`, `~/.config/gogcli/credentials.json`, `~/.claude/.credentials.json`,
   `~/.codex/auth.json`, `~/.xurl`), SSH keys, the Orca hook file, the persistent chezmoi command,
   rustup/Rust/Cargo, any real (non-symlink) directory
   under `~/.agents/skills` that isn't backed by a canonical repo, `mise doctor`, plus:
   - **Per-hub checks** (from `~/.agents/hubs.md`): hub missing on disk → MISSING (fix:
     re-run apply, which triggers hub sync); working tree dirty → WARNING; ahead/behind
     its upstream → reported from local information only (doctor does not fetch, so
     "behind" can be stale).
   - **Workspace-local skill projections** (from `~/.agents/workspace-skills.local.md`):
     missing canonical directories, missing root discovery links, wrong targets, and
     non-symlink conflicts are reported. A workspace canonical skill that is also linked
     from a home-global discovery directory is reported as a scope leak.
   - **Tool path-conflict check**: any tool whose `command -v` resolves outside
     `~/.local/share/mise` → WARNING (duplicate brew/system install shadow-managed by
     mise; see Conflict Resolution Policy).
   - **Workspace migration checks**: legacy Workspace paths or parent-root AGENTS links,
     wrong Workspace remotes, a missing global Workspace hook, and stale remote-control
     start paths are reported.

4. Walk the user through each MISSING item — see "Handling doctor Gaps" below. Do not
   treat the run as complete until doctor is clean or the user has explicitly accepted
   remaining gaps (e.g. no Orca on this machine).

## Handling doctor Gaps

Most of these cannot be done by the agent alone — they need an interactive login or a
manual transfer. For each MISSING/WARNING item, tell the user what command to run and why:

- `~/.claude/.credentials.json` missing → have the user run `claude` and log in
  interactively (`! claude` from the agent, or a separate terminal).
- `~/.codex/auth.json` missing → have the user run `codex login`.
- `~/.llmx/credentials` or `~/.config/gogcli/credentials.json` missing → these are
  copy-only (not re-derivable by a login flow on this machine); `scp` them from the main
  machine (see the topology note in Mental Model), then `chmod 600`.
- `~/.xurl` missing or its OAuth2 refresh token is invalid → do not copy the file from
  another machine. Configure the X app on this machine if needed, then have the user run
  `xurl auth oauth2 <username>` interactively. Each machine keeps its own OAuth state.
- SSH key missing → `gh auth login` + `gh ssh-key add`, or manual `ssh-keygen` +
  registering the public key on GitHub.
- Orca hook missing → confirm whether the user actually wants Orca on this machine; if
  yes, installing the Orca app is the prerequisite, the hook file follows from that.
- A real (non-symlinked) directory under `~/.agents/skills` → two legitimate resolutions:
  if it's an **intentional machine-local skill** (e.g. `orca-cli`, installed by the Orca
  app), add its name (one per line, `#` comments allowed) to
  `~/.agents/skills-local-allow.txt` — a machine-local, non-chezmoi-managed allowlist
  that doctor reads; listed skills report OK instead of WARNING. Otherwise it's drift;
  hand off to `global-skill-workflow`'s conflict-handling, don't resolve it here.
- Hub MISSING → the agent CAN fix this one: re-run `chezmoi apply` (or `chezmoi update`),
  which re-triggers the hub sync script (prefix `HARNESS_SYNC_FORCE=1` if the last run
  was within the hour, or the throttle will skip it).
- `rustup` or the stable Rust toolchain missing → the agent CAN fix this one: re-run
  `chezmoi apply`; the Rust pre-apply hook skips healthy installs and repairs only the
  missing pieces.
- Hub dirty / diverged (WARNING) → do not auto-resolve; see Conflict Resolution Policy.
- Tool resolving outside `~/.local/share/mise` (WARNING) → duplicate management; see
  Conflict Resolution Policy.

## Conflict Resolution Policy (follower machine)

The git remotes are canonical — the main machine pushes continuously. On a follower
machine, local divergence is presumed accidental: **discarding the local diff is the
default**, after inspection.

- **chezmoi targets**: if a target changed locally since the last apply, `chezmoi apply`
  prompts before overwriting — and in a non-interactive run the prompt gets EOF, exits 1,
  and the local diff stays in place. Resolution: run `chezmoi diff` to see what would
  change; if the local edits are not worth keeping (the default assumption here), run
  `chezmoi update --force` (`--force` is a global flag shared by apply/update/init;
  verified). Do NOT `chezmoi re-add` from a follower machine — that pushes local state
  into the canonical source, which is only correct when deliberately changing the source
  of truth; for that, switch to the Push Direction flows below.
- **Duplicate tool installs (brew/system vs mise)**: mise activation puts its shims at
  the front of PATH, so in a new shell the mise-managed tool wins regardless. doctor
  surfaces the duplicates (WARNING when `command -v` resolves outside
  `~/.local/share/mise`); guide the user to uninstall the brew copy or fix PATH ordering
  so the shadowed copy doesn't resurface in odd contexts.
- **The chezmoi source repo itself**: `chezmoi update` can fail with
  `error: The following untracked working tree files would be overwritten by checkout`
  or an autostash-related `chezmoi: git: exit status 1` — e.g. when an untracked file
  sat in the source (a stray `dot_zsh.d/site-functions/_docker`) and the canonical repo
  later started tracking a file of the same name. Recovery, with the canonical remote
  winning:

  ```sh
  cd ~/.local/share/chezmoi
  git fetch origin
  git clean -nd          # preview which untracked files will be deleted
  git clean -fd
  git reset --hard origin/main
  chezmoi apply -v --force
  ```
- **Hub and skill repos**: sync only ever fast-forwards (`--ff-only`) on a clean tree.
  Dirty or diverged repos are warned and skipped, never auto-resolved — hubs have their
  own auto-sync hooks pushing from the machine where work happens, so a dirty follower
  hub usually means work happened here that those hooks will handle, or that needs a
  human decision.
- **Workspace path migration**: a single legacy copy is moved, not copied, so dirty and
  unpushed work survives. If both paths exist, automation proceeds only when history and
  dirty state identify a safe winner; redundant copies move to `~/.Trash`. If doctor
  still reports a legacy path, inspect both repos and decide manually.

Note on `-v`: `chezmoi apply -v` / `update -v` shows each file's diff through a pager,
which stops after every file on a drift-heavy machine (it looks hung at a `lines 1-37`
prompt). When an agent runs these, or you want the log to stream through, add
`--no-pager` (verified working: `chezmoi apply -v --force --no-pager`).

## Daily Sync (existing machine)

```sh
chezmoi update
```

One command now refreshes everything: dotfiles, mise tools (run_onchange, fires when
`~/.config/mise/config.toml` changed), skill repos, and hubs — the 20/30 `run_after`
hooks run on every apply, so no separate mise, skill-bootstrap, or hub-sync step is
needed. Two behaviors to know:

- **Throttle**: if the 20/30 stages ran successfully within the last hour they print a
  スキップ banner and do nothing; prefix with `HARNESS_SYNC_FORCE=1` when you need them
  to run right now (e.g. another machine just pushed a new skill). Hub sync ignores the
  throttle when any registered hub path is missing, so path migration never waits for
  the one-hour window.
- **bootstrap pull results**: the bootstrap Summary now includes `pulled` /
  `pull skipped (dirty)` / `pull failures`. A pull failure (e.g. a repo sitting on a WIP
  branch with no upstream) is a warning only, never fatal — mention it to the user and
  move on.
- **Workspace Stop auto-push**: every hub marked `- 自動同期: true` is checked at each
  Claude/Codex Stop, regardless of cwd. Dirty hubs are committed and pushed; clean hubs
  with ahead commits retry push. A short-lived lock prevents simultaneous Stop hooks
  from racing. Private workspace configuration may add companion repositories that sync
  only when the session cwd belongs to their workspace scope; keep those additions in the
  private hook rather than the public hub registry.

If the update stops on an overwrite prompt (or fails non-interactively with a local
diff), follow the Conflict Resolution Policy above. Run `bash ~/.local/share/chezmoi/scripts/doctor.sh` afterward if there's
any doubt about credential or hook state (e.g. after a long gap since last sync, or before
relying on a tool that needs auth).

# Push Direction (chezmoi source ← this machine)

## Detect Management

Before editing any dotfile-like path, check whether it's actually under chezmoi. The
authoritative test:

```sh
chezmoi source-path ~/.config/ghostty/config   # succeeds only if managed
```

(`chezmoi managed` can help browse or search the managed set when exploring.)

- Managed → follow the Edit Flow below.
- Not managed → treat it as an ordinary file edit. Only bring it under chezmoi management
  if the user explicitly asks (see Add/Remove); don't add new files proactively.

## Edit Flow

Use whenever a task changes settings that happen to live under chezmoi, whether or not
chezmoi is mentioned by name.

1. Locate the source file: `chezmoi source-path <target>`.
2. **Secret review (before any source write)**: confirm the content you're about to add
   contains no API keys, tokens, passwords, private keys, or internal hostnames.
   Optionally run the repo's linter early: `cd "$(chezmoi source-path)" && npx secretlint <path>`
   — catching a secret here avoids history repair later.
3. Edit the source file directly (not the rendered target) unless the user specifically
   wants a target-only experiment.
4. Preview: `chezmoi diff` (or scoped: `chezmoi diff <target>`). This validates the
   rendered result; it is **not** a secret gate — that already happened in step 2.
5. Apply: `chezmoi apply <target>` (or whole tree). Treat apply as a real write to $HOME.
6. Publish. Direct source edits are not auto-committed, so run:

   ```sh
   git -C "$(chezmoi source-path)" add <source-file>
   git -C "$(chezmoi source-path)" commit -m "..."
   git -C "$(chezmoi source-path)" push   # secretlint runs here (pre-push)
   ```

   If the source was changed via a chezmoi command instead, autoCommit + autoPush already
   ran — skip this and just verify the push.
7. If the target was edited first (e.g. a quick local test), confirm it works, run the
   secret review on the resulting content, then reconcile with `chezmoi re-add <target>`
   (auto-commits and pushes). Note `re-add` will not overwrite `.tmpl` source files, so
   template edits must go directly into the source.
8. Templates: preserve `{{ }}` syntax; verify rendered output with `chezmoi diff` or
   `chezmoi execute-template` rather than guessing.

## Drift Reconciliation (fold $HOME changes into the source)

Use when $HOME has drifted from the chezmoi source (manual edits, tool-managed config,
etc.) and the drift should be folded back in — i.e. the local changes are the ones worth
keeping. (If the drift is accidental and the remote should win, that's the pull-direction
Conflict Resolution Policy instead.)

1. Enumerate drift: `chezmoi status`.
2. For each drifted target, inspect the change: `chezmoi diff <target>`.
3. **Secret review** (mandatory, before touching source state): scan the diff by eye for
   API keys, tokens, passwords, private keys, internal hostnames, and similar values.
   Optionally also run `npx secretlint` from the source repo on the affected paths.
4. If clean, fold it in: `chezmoi re-add <target>` — this commits and pushes automatically.
5. If it contains secrets, do not re-add. Propose templating the file instead (see
   Secrets Handling) so the secret is externalized before it's folded in.
6. After processing all drifted files, re-run `chezmoi status` to confirm nothing is
   left, and confirm the push actually succeeded (see Report Back).

## Secrets Handling

- Convert files that carry secrets into `.tmpl` sources; inject the real value at apply
  time — never hardcode it in the source tree.
- Injection sources: an environment variable, a password manager, or `chezmoi data`
  (the `[data]` table in `chezmoi.toml`). Before putting a secret in `[data]`, verify
  that `~/.config/chezmoi/chezmoi.toml` itself is neither chezmoi-managed nor git-tracked
  — otherwise the secret only moves, it doesn't hide. Secrets belong only in local
  untracked files, env vars, or a password manager.
- `private_` only tightens file permissions on the rendered target (e.g. `0600`); it
  does **not** stop the content from being committed and pushed to the remote. Don't
  rely on it for confidentiality.
- Once a file is templated, `chezmoi re-add` will not clobber it, so templating is the
  durable fix for recurring drift that would otherwise leak secrets.

## Recovery When secretlint Blocks a Push

Because the hook runs at pre-push, a blocked push still leaves the secret committed
locally. Until history is repaired, **do not run any source-mutating chezmoi command** —
autoCommit would stack new commits on top of the tainted one.

1. Remove or templatize the secret by editing the source file manually (not via chezmoi);
   confirm with `git -C "$(chezmoi source-path)" diff`.
2. Repair history in `$(chezmoi source-path)`:
   - Tip commit only: `git commit --amend`.
   - Multiple commits: `git reset --soft <commit-before-the-secret>`, then recommit cleanly.
3. Verify: check `git log` for the secret and optionally re-run `npx secretlint` on the
   affected paths.
4. Push explicitly: `git -C "$(chezmoi source-path)" push`. The earlier push was blocked,
   so the remote was never tainted — a normal push suffices, no force push needed.
5. Only if the secret actually reached the remote (e.g. the hook was bypassed): treat it
   as compromised and rotate/revoke it. Rewriting history is not sufficient once a secret
   has left the local machine.

## Add / Remove Managed Files

- Add a new file to chezmoi management **only on explicit request**. Run the secret
  review on its contents before `chezmoi add`, since add triggers autoCommit/autoPush
  immediately.
- For a brand-new dotfile with no existing target, create the source file directly using
  chezmoi naming conventions (`dot_zshrc`, `private_`, `executable_`, `.tmpl`), verify
  with `chezmoi diff`, then commit and push manually — direct creation does not
  auto-commit.
- Removal — decide, preview, execute, verify:
  1. Confirm with the user: stop tracking only (keep the target in $HOME), or also delete
     the target?
  2. Preview the impact where possible (`chezmoi diff`, inspect the source file).
  3. Execute: `chezmoi forget <target>` for source-only removal, or `chezmoi remove <target>`
     to also delete the target from $HOME (both auto-commit/push).
  4. Verify with `chezmoi status` and `git -C "$(chezmoi source-path)" log -1 --oneline`.

## Report Back (push direction)

Summarize:

- Which source files changed, and how they were published — autoCommit/autoPush (which
  chezmoi command) or manual commit/push — with the resulting commit hash
  (`git -C "$(chezmoi source-path)" log -1 --oneline`).
- Result of the secret review (clean / templated / rotation needed).
- Whether the push actually succeeded, or is stuck behind secretlint (and what recovery
  step is still pending).
- Any remaining drift (`chezmoi status` non-empty) or unrelated dirty state left untouched.

# Agent Behavior

- Run the commands above directly (curl one-liner, `chezmoi update`, `doctor.sh`) rather
  than just describing them.
- Read and interpret doctor's output for the user; don't just paste it raw. Group
  findings into "nothing to do", "needs a login command", and "needs manual transfer".
- Never attempt interactive logins (`claude`, `codex login`, `gh auth login`) on the
  user's behalf — these require a real terminal/browser interaction. Tell the user the
  exact command to run themselves.
- If doctor reports skill-registry drift or a skill conflict, hand off to
  `global-skill-workflow` rather than resolving symlinks here.

# Out of Scope (see these skills instead)

- **Skill authoring/sync details**: creating a new skill, updating an existing one,
  migrating between repos, the exact symlink reconciliation algorithm → `global-skill-workflow`.
- **Agent memory operation**: GC, brief extraction, memory conventions, hub-registry
  semantics → `feedback-assetization`. (The hub repo clone/pull that makes `agent-memory/`
  present on this machine IS this skill's scope, via the hub sync script.)

Do not duplicate those skills' procedures here; link out to them instead.
