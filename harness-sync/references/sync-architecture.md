## Mental Model

Four things sync independently, by four different mechanisms. Nothing here needs to be
invented — these are already wired up:

| What | Source of truth | Sync mechanism |
|---|---|---|
| Dotfiles (`~/.zsh.d`, `~/.claude/{CLAUDE.md,settings.json,keybindings.json}`, `~/.codex/{config.toml,hooks.json,AGENTS.md,rules}`, `~/.agents/{hubs.md,workspace-sync-hook.sh}`, `~/.config/mise`, ...) | `git@github.com:maguroid/dotfiles.git` (branch `main`), local checkout `~/.local/share/chezmoi` | chezmoi (`chezmoi init --apply` first time, `chezmoi update` thereafter) |
| Runtime/CLI tools (node, uv, etc.; Codex CLI is the exception below) | `~/.config/mise/config.toml` (itself chezmoi-managed) | mise (`mise install`, triggered automatically by a chezmoi run_onchange hook whenever the config changes) |
| macOS system-integrated apps (currently azooKey and Hammerspoon) | `~/.config/homebrew/Brewfile` (chezmoi-managed) | Homebrew Cask (`brew bundle install --global --no-upgrade`, triggered by a run_onchange hook whenever the Brewfile changes). Hammerspoon is then started or reloaded; its synced `~/.hammerspoon/init.lua` enables launch at login. Accessibility approval remains per-device. |
| Codex CLI | OpenAI's standalone package; installation is machine-local | Use the official installer on each Mac; do not declare Codex in mise. Follow [references/codex-cli.md](./codex-cli.md). |
| Tailscale OSS client on macOS | The two mise Go-backend declarations sync; the root-owned daemon copy, LaunchDaemon registration, and Tailnet login are machine-local | `mise install` provides `tailscale` / `tailscaled`; each Mac runs the upstream `install-system-daemon` and authenticates itself. See [references/tailscale-macos.md](./tailscale-macos.md). |
| Rust toolchain (`rustup`, `rustc`, `cargo`) | rustup stable channel; bootstrap logic in the chezmoi source | rustup (`run_before_05-install-rustup.sh`; shell PATH remains chezmoi-managed) |
| Wrangler profile policy | dotfiles hook `run_after_45-configure-wrangler-profiles.sh`; OAuth profile files remain machine-local | after both named profiles exist, every apply enforces personal as default and binds `$HOME/ghq/github.com/maguroid` to `personal` and `$HOME/ghq/github.com/hashigodakainc` to `hashigodaka`; doctor reports missing profiles or drift |
| Global and registered skill repos (`global-skill-workflow`, this skill, ...) | `maguroid/skills` (agent-neutral) + `maguroid/cc-skills` (Claude Code-only) + `maguroid/codex-skills` (Codex-only) + any private repos in `~/.agents/skills-repos.local.md` | pull: clone + pull + `bootstrap.sh` (pulls clean registered repos `--ff-only`, then symlinks into home-global discovery directories according to scope; `workspace-only` entries are fetched but not globalized), run on **every** chezmoi apply via a run_after hook (1-hour throttle). push: the three built-in repos auto-commit+push via a global Claude Code Stop hook (`global-skill-workflow/scripts/auto_sync.sh`); registry repos stay manual — see `global-skill-workflow` |
| Workspace-local skills | Each owning workspace repository's `.agents/skills` | `$HOME/.agents/workspace-skills.local.md` maps the owner/organization folder actually opened as the harness root to its canonical workspace skills. After hub sync, the `global-skill-workflow` reconciler projects links into that root's `.agents/skills` and `.claude/skills`; it never globalizes them. |
| Hub repos, incl. agent memory (each hub — e.g. Workspace-Me, Workspace-Foo — carries its `agent-memory/`) | hub registry `~/.agents/hubs.md` (chezmoi-managed; `- 自動同期: true` enables global Stop auto-push) | path migration runs before hub sync; then missing repos are cloned and clean repos pulled. The Stop hook commits/pushes every dirty or ahead auto-sync hub, independent of cwd. The private hook may also add narrowly scoped companion repositories such as a team wiki. |

Credentials and machine-specific state are **not** distributed by any of the above and
must be established per machine: `~/.config/gogcli/credentials.json`,
`~/.claude/.credentials.json`, `~/.codex/auth.json`, per-device xurl OAuth state in
`~/.xurl`, SSH keys, and Tailscale state under `/Library/Tailscale`.
Wrangler OAuth files under `~/.config/.wrangler/config/*.toml` are also machine-local and
must never be committed; only their expected profile names, default policy, and directory
bindings are reproduced by the managed hook.

The user's machines form a hub-and-spoke topology: one always-on **main machine** at home
(the canonical push source for dotfiles/hubs) and one or more portable **follower machines**.
Authentication files and tokens are outside the sync lane: never copy them from the main
machine or another device as part of bootstrap or daily sync. Configure each tool locally
on each machine using its own login or secure setup flow. In particular, never copy
`~/.xurl` between machines: OAuth2 refresh-token rotation can invalidate another machine's
stored token. Re-register the app credentials and authenticate independently on each
machine. Preserve the app's existing callback URI exactly; for `xurl` through v1.2.2 the
built-in default is `http://localhost:8080/callback`.

Properties of the chezmoi lane that both directions depend on:

- The source repo (`~/.local/share/chezmoi`, remote `github.com:maguroid/dotfiles`,
  branch `main`) is the single source of truth. Treat it, not $HOME, as canonical.
- The source repo's `.chezmoi.toml.tmpl` generates the machine-local
  `~/.config/chezmoi/chezmoi.toml` during `chezmoi init`, setting
  `[git] autoCommit = true` and `autoPush = true`. `doctor.sh` verifies both the file and
  the effective values. **chezmoi commands that modify the source state** (`chezmoi add`,
  `chezmoi re-add`, `chezmoi edit`, `chezmoi forget`, `chezmoi remove`, …) then commit
  and push to the remote automatically. Directly editing a source file with an editor or
  Write/Edit tools does **not** trigger this — such changes need a manual commit and push.
- Because a chezmoi command pushes the moment it runs, secret review must happen
  **before** the source state changes, not after.
- lefthook + secretlint run at **pre-push** (not pre-commit). A rejected push still
  leaves the offending commit sitting locally on `main` — see Recovery below.
- The managed set is large, spanning `~/.zsh.d`, `~/.config/nvim`, `~/.claude`,
  `~/.codex`, and more. Repo-only tooling at the source root is excluded via
  `.chezmoiignore` and is not distributed to $HOME.
