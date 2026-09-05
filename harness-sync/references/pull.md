# Pull Direction (this machine ← remotes)

## New Machine Setup

**Existing machine with a stale source?** If chezmoi is already installed but the source
checkout is old, the one-liner below will NOT bring the environment up to date. Telltale
signs: `chezmoi status` works yet today's `../scripts/` are missing, or skill links are
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
   - Before apply, chezmoi renders the source repo's `.chezmoi.toml.tmpl` into the
     machine-local `~/.config/chezmoi/chezmoi.toml`. This enables source-mutating
     chezmoi commands to auto-commit and auto-push on that machine.
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
   - `run_onchange_after_12-homebrew-bundle.sh` runs
     `brew bundle install --global --no-upgrade` when the managed Brewfile changes. It
     installs missing macOS system-integrated apps without upgrading existing ones.
   - `run_onchange_after_13-start-hammerspoon.sh` starts Hammerspoon after its app or
     config changes, or reloads a running instance through `hs.ipc`. The synced config
     enables launch at login. macOS Accessibility approval cannot be distributed and
     must be granted once on each Mac.
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
     one-liner covers agent-memory availability too.
     After hub sync, the same hook calls the `global-skill-workflow` workspace reconciler,
     which reads `~/.agents/workspace-skills.local.md` and exposes each workspace's local
     skills from the higher-level owner/organization folder actually used as the harness
     root. This inexpensive reconciliation also runs when the hub pull itself is throttled.
   - `run_after_35-refresh-workspace-remote-control.sh` recreates existing
     `claude-rc-me` / `claude-rc-hsg` tmux sessions only when their start path is a
     migrated legacy Workspace.
   - `run_after_45-configure-wrangler-profiles.sh` never performs an interactive login.
     When machine-local `personal` and `hashigodaka` profiles exist, it makes `personal`
     the default and binds the personal/company ghq owner roots to their matching profiles.
     Missing profiles produce warnings and are left for the user to authenticate locally.

   The 20/30 stages are `run_after` hooks: they run on **every** apply, but with a
   1-hour throttle — within an hour of the last successful run they print
   `==> [3/4] スキップ（前回実行から1時間未満。HARNESS_SYNC_FORCE=1 で強制実行）` and skip
   (stamps: `~/.cache/harness-sync/{skills,hubs}-last-run`). Set `HARNESS_SYNC_FORCE=1`
   to force them.

3. Install or refresh the standalone Codex CLI on each Mac. Treat it as an intentional
   exception to mise-managed tools and follow
   [references/codex-cli.md](./codex-cli.md).

4. Run the diagnostic script and interpret its output for the user:

   ```sh
   bash ~/.local/share/chezmoi/scripts/doctor.sh
   ```

   It always exits 0 (even with MISSING items) and prints a summary count at the end —
   treat a nonzero MISSING count as a checklist, not a failure. It checks: the local
   chezmoi config and effective `autoCommit` / `autoPush` values, auth files
   (`~/.config/gogcli/credentials.json`, `~/.claude/.credentials.json`,
   `~/.codex/auth.json`, `~/.xurl`), SSH keys, the persistent chezmoi command,
   rustup/Rust/Cargo, Hammerspoon app/config/process/Accessibility/launch-at-login,
   Wrangler named profiles/default/bindings, any real (non-symlink) directory
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
   - **Tailscale on macOS**: verify the mise-managed OSS binaries, native root-owned
     LaunchDaemon copy, binary equality, per-device login, SSH server flag, and absence
     of the GUI/Homebrew variants. Follow [references/tailscale-macos.md](./tailscale-macos.md)
     for repair and update commands; never copy another device's state.
   - **Workspace migration checks**: legacy Workspace paths or parent-root AGENTS links,
     wrong Workspace remotes, a missing global Workspace hook, and stale remote-control
     start paths are reported.

5. Walk the user through each MISSING item — see "Handling doctor Gaps" below. Do not
   treat the run as complete until doctor is clean or the user has explicitly accepted
   remaining gaps.

## Handling doctor Gaps

Most of these cannot be done by the agent alone — they need an interactive login or local
credential setup. For each MISSING/WARNING item, tell the user what command to run and why:

- `codex` missing or resolving only to the ChatGPT app-bundled executable → follow
  [references/codex-cli.md](./codex-cli.md); do not add Codex to mise.
- `~/.config/chezmoi/chezmoi.toml` missing → the machine predates the config template or
  bootstrap was incomplete. With an up-to-date clean source, run `chezmoi init` to
  regenerate it from `.chezmoi.toml.tmpl`, then verify both effective values with
  `chezmoi dump-config`. If the file exists but either value is false, inspect and edit
  the local file; do not copy machine-local `[data]` or secrets from another device.
- `~/.claude/.credentials.json` missing → have the user run `claude` and log in
  interactively (`! claude` from the agent, or a separate terminal).
- `~/.codex/auth.json` missing → have the user run `codex login`.
- `~/.config/gogcli/credentials.json` missing → run `gog auth setup <email>` locally and
  complete its guided OAuth setup. Do not import credentials from another machine.
- `~/.xurl` missing or its OAuth2 refresh token is invalid → do not copy the file from
  another machine. Follow [references/xurl-oauth.md](./xurl-oauth.md); each
  machine keeps its own OAuth tokens.
- Wrangler `personal` / `hashigodaka` profile missing → run `wrangler auth create personal`
  and/or `wrangler auth create hashigodaka` interactively on that machine, choosing the
  corresponding Cloudflare account, then run `chezmoi apply`. Do not copy or commit the
  OAuth TOML files. The apply hook sets personal as default and restores both owner-root
  bindings; doctor verifies the resulting policy.
- SSH key missing → `gh auth login` + `gh ssh-key add`, or manual `ssh-keygen` +
  registering the public key on GitHub.
- A real (non-symlinked) directory under `~/.agents/skills` → two legitimate resolutions:
  if it's an **intentional machine-local skill**, add its name (one per line, `#` comments allowed) to
  `~/.agents/skills-local-allow.txt` — a machine-local, non-chezmoi-managed allowlist
  that doctor reads; listed skills report OK instead of WARNING. Otherwise it's drift;
  hand off to `global-skill-workflow`'s conflict-handling, don't resolve it here.
- Hub MISSING → the agent CAN fix this one: re-run `chezmoi apply` (or `chezmoi update`),
  which re-triggers the hub sync script (prefix `HARNESS_SYNC_FORCE=1` if the last run
  was within the hour, or the throttle will skip it).
- `rustup` or the stable Rust toolchain missing → the agent CAN fix this one: re-run
  `chezmoi apply`; the Rust pre-apply hook skips healthy installs and repairs only the
  missing pieces.
- Hammerspoon app or `hs` CLI missing → the agent CAN fix this one: re-run
  `chezmoi apply`; the managed Brewfile installs the Cask. If the process is not running,
  run `open -a Hammerspoon`. If Accessibility is missing, open System Settings → Privacy
  & Security → Accessibility and have the user enable Hammerspoon; this approval is
  intentionally per-device and cannot be copied. The synced config enables launch at
  login and loads `hs.ipc`, so restart Hammerspoon if doctor reports either one missing.
- Hub dirty / diverged (WARNING) → do not auto-resolve; see Conflict Resolution Policy.
- Tool resolving outside `~/.local/share/mise` (WARNING) → duplicate management; see
  Conflict Resolution Policy.
- Tailscale daemon/login/SSH/duplicate-install findings → keep the mise declarations as
  the only synced state and repair the local Mac using
  [references/tailscale-macos.md](./tailscale-macos.md).

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

One command refreshes the managed sync lanes: dotfiles, mise tools (run_onchange, fires
when `~/.config/mise/config.toml` changed), Homebrew Casks (run_onchange, fires when the
Brewfile changed), Hammerspoon startup/config reload, skill repos, and hubs — the 20/30
`run_after` hooks run on every apply, so no separate mise, Cask, skill-bootstrap, or
hub-sync step is needed. The standalone Codex CLI and machine-local credentials or macOS
privacy approvals are explicit exceptions.
Behaviors to know:

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
- **Wrangler profile policy**: after the sync stages, the managed hook reasserts personal
  as the default and the personal/company owner-root bindings whenever both local named
  profiles are available. Credentials themselves never leave the machine.
- **Codex CLI updates**: `chezmoi update` and `mise install` do not update it. Follow
  [references/codex-cli.md](./codex-cli.md) on each Mac.

If the update stops on an overwrite prompt (or fails non-interactively with a local
diff), follow the Conflict Resolution Policy above. Run `bash ~/.local/share/chezmoi/scripts/doctor.sh` afterward if there's
any doubt about credential or hook state (e.g. after a long gap since last sync, or before
relying on a tool that needs auth).
