---
name: global-skill-workflow
description: Create, update, migrate, sync, or organize global and workspace-root-scoped skills. Use when an agent is asked to make a global skill, install a personal/global skill, update an existing skill, sync skills from remote repositories, move skills between discovery directories, manage symlinks for skill discovery, or expose a workspace's local skills from the higher-level folder that is actually opened as the harness root. Global canonical repos are `$HOME/ghq/github.com/maguroid/skills` (personal, default), `$HOME/ghq/github.com/maguroid/cc-skills` (Claude Code-only), and `$HOME/ghq/github.com/maguroid/codex-skills` (Codex-only), plus private registry repos. Workspace projections are declared in `$HOME/.agents/workspace-skills.local.md`.
---

# Global Skill Workflow

## Core Rule

Use `$HOME/ghq/github.com/maguroid/skills` as the canonical source for user-created global skills. Make both `$HOME/.agents/skills/<skill-name>` and `$HOME/.claude/skills/<skill-name>` symlinks to each canonical skill directory.

Use the active agent's system skill authoring and validation workflow when creating or updating skill content. This skill controls placement, linking, migration, and validation targets.

For workspace-specific skills, keep the canonical directories inside the owning workspace repository at `.agents/skills/<skill-name>`. When sessions open a higher-level owner or organization folder instead of that repository, project each canonical skill into both `<opened-root>/.agents/skills` and `<opened-root>/.claude/skills`. Do not globalize context-specific skills merely to make them discoverable.

## Choosing the Canonical Repo

Three public canonical repos exist, plus optional private repos in a local registry. Choose by audience and harness before creating or migrating a skill:

- **Personal skills** (the user's own tooling, machine setup, personal workflows; agent-neutral): `$HOME/ghq/github.com/maguroid/skills` (default; public).
- **Claude Code-only skills** (skills that only make sense inside the Claude Code harness — e.g. they orchestrate Claude Code-specific delegation or tooling, like `codex-delegate`): `$HOME/ghq/github.com/maguroid/cc-skills` (GitHub: `maguroid/cc-skills`; public).
- **Codex-only skills** (skills that rely on Codex-specific tools, metadata, or collaboration semantics): `$HOME/ghq/github.com/maguroid/codex-skills` (GitHub: `maguroid/codex-skills`; public).
- **Additional repos (including private repos)**: registered in the machine-local registry `$HOME/.agents/skills-repos.local.md`. **Read that file before choosing a repo** — if the skill's audience matches an entry there, use that repo. This SKILL.md lives in a public repo, so private repo names, org names, and audience details belong ONLY in the registry file, never here. When creating or updating a skill in an additional repo, keep following this workflow's steps with that repo's path, skills path, and symlink scheme as declared by its registry entry.

Symlink scheme by repo:

- Personal skills — and private-registry repos unless their entry says otherwise — link into **both** `$HOME/.agents/skills` and `$HOME/.claude/skills`.
- Claude Code-only skills (cc-skills) link into **`$HOME/.claude/skills` only** — never into `$HOME/.agents/skills`, which is the agent-neutral discovery directory read by other harnesses (codex etc.).
- Codex-only skills (codex-skills) link into **`$HOME/.codex/skills` only** — never into the agent-neutral or Claude Code discovery directories.

The Sync Workflow below covers all registered repos at once via `bootstrap.sh` (pull + symlink reconciliation, per each repo's symlink scheme and skills path). When a skill's audience or harness scope changes, move it between repos, commit both repos, and repoint discovery links to match the target scheme. Remove links from discovery directories that no longer own the skill.

## Paths

- Canonical repos: `$HOME/ghq/github.com/maguroid/skills` (personal, default) / `$HOME/ghq/github.com/maguroid/cc-skills` (Claude Code-only) / `$HOME/ghq/github.com/maguroid/codex-skills` (Codex-only) / private repos per `$HOME/.agents/skills-repos.local.md`
- Active agent discovery directory (agent-neutral): `$HOME/.agents/skills`
- Claude discovery directory: `$HOME/.claude/skills`
- Codex discovery directory: `$HOME/.codex/skills`
- Skill authoring and validation tools: use the active agent's system skills or built-in skill tooling.
- Workspace projection registry: `$HOME/.agents/workspace-skills.local.md` (machine-local/private, chezmoi-managed)
- Workspace projection reconciler: `global-skill-workflow/scripts/reconcile_workspace_skills.sh`

Use `$HOME` rather than an OS-user-specific absolute home path in skill instructions. Do not use a non-hidden `$HOME/claude/skills` directory unless the user explicitly configures or requests that alternate location.

## Workspace-root-scoped Skills

Use this layout when a workspace repository owns context-specific skills but the harness is normally opened from a parent owner/organization directory:

```text
<opened-root>/.agents/skills/<name>  -> <workspace>/.agents/skills/<name>
<opened-root>/.claude/skills/<name>  -> <workspace>/.agents/skills/<name>
<workspace>/.agents/skills/<name>    # canonical, Git-tracked
```

Keep `.agents/skills` as the only real skill directory inside the workspace. If the workspace also supports being opened directly, make each `<workspace>/.claude/skills/<name>` a relative symlink to `../../.agents/skills/<name>`.

Register projections in `$HOME/.agents/workspace-skills.local.md`:

```markdown
### Workspace-Example

- Root: `$HOME/ghq/github.com/example-owner`
- Skills: `$HOME/ghq/github.com/example-owner/Workspace-Example/.agents/skills`
```

The registry may contain private paths or organization names, so manage it through the private chezmoi repository and never commit its contents to this public repository. The reconciler also reads the chezmoi source copy so changes can be tested before apply.

Run the reconciler after workspace repositories have been cloned or pulled:

```sh
bash "$HOME/ghq/github.com/maguroid/skills/global-skill-workflow/scripts/reconcile_workspace_skills.sh"
```

It creates missing discovery links, leaves correct links unchanged, reports real directories or foreign symlinks as conflicts without overwriting them, and reports stale links without deleting them. A chezmoi post-apply hook should invoke it after hub synchronization. Skill discovery is resolved at session start, so verify changes in a new session rooted at each registered `Root`.

When consolidating pre-existing duplicates, diff the harness directories first. Merge the newest rules into the workspace `.agents/skills` canonical copy, replace `.claude/skills/<name>` with a relative link, and only then enable the parent-root projection. Do not choose one side solely by directory name or timestamp.

## New Machine Bootstrap

Use `$HOME/ghq/github.com/maguroid/skills/bootstrap.sh` when setting up global skills on a new terminal or machine. The script is idempotent and uses only `$HOME`-relative paths. It always knows the three public canonical repos (`maguroid/skills` as agent-neutral, `maguroid/cc-skills` as Claude Code-only, and `maguroid/codex-skills` as Codex-only), and if `$HOME/.agents/skills-repos.local.md` exists, it reads the additional repo entries declared there. When a chezmoi source copy exists at `$HOME/.local/share/chezmoi/dot_agents/skills-repos.local.md`, the script reads that too and de-duplicates entries by path; this lets the source registry be tested before applying it. The registry is machine-local/private data; this public repo must mention only the registry format and never private organization names, repository names, or audiences.

Registry entries use `- Path: \`...\``, `- GitHub: \`owner/repo\``, and `- Symlink scheme: ...`; they may also include `- Skills path: \`<subdir>\``. When `Skills path` is omitted, the repo is treated like the personal repo: top-level directories containing `SKILL.md` are skills. When it is `skills`, top-level directories under that subdirectory are skills. When it is `.`, the repository root itself is one skill, and the link name is the repository directory name.

The bootstrap script clones any missing canonical repo with its SSH GitHub URL. For repos that already exist, it also pulls: clean working tree → `git pull --ff-only`; dirty → warn and skip; pull failure (e.g. a WIP branch with no upstream) → warning only, the run continues. The Summary reports `pulled`, `pull skipped (dirty)`, and `pull failures` alongside the link counts. Clone failures for the three built-in public repos are fatal; clone failures for registry repos are warning-only so private or optional repos do not make chezmoi hooks fail forever on machines without access.

After clone-and-pull, the script reconciles discovery symlinks: create missing symlinks, repair broken symlinks whose intended target is the canonical skill directory, leave already-correct links untouched, and report real directories or foreign symlinks as conflicts without overwriting them. Agent-neutral repos link each top-level `SKILL.md` directory into both `$HOME/.agents/skills` and `$HOME/.claude/skills`. Claude Code-only repos link into `$HOME/.claude/skills` only. Codex-only repos link into `$HOME/.codex/skills` only. Matching links in a discovery directory outside the repo's scheme are reported as strays and left untouched.

The user's private dotfiles repo may distribute `$HOME/.agents/skills-repos.local.md` and a chezmoi `run_after` hook script that wraps `bootstrap.sh` (currently `run_after_20-bootstrap-global-skills.sh`: it first pulls the `maguroid/skills` repo itself when clean so a stale `bootstrap.sh` is never used, then runs it on every apply with a 1-hour throttle; `HARNESS_SYNC_FORCE=1` forces a run). With that setup, `chezmoi init --apply` / `chezmoi update` installs the private registry, clones `maguroid/skills` if needed, and runs `bootstrap.sh` automatically. Keep private registry contents in the private dotfiles repo only, never in this public skill repo.

## New Global Skill Workflow

1. Choose the canonical repo by audience and harness (see "Choosing the Canonical Repo"), and a hyphen-case skill name under 64 characters.
2. Confirm the canonical path does not already exist in the chosen repo (and check the other repos for a name collision):

```sh
test -e "<chosen-repo>/<skill-name>"
```

3. Initialize the skill in the chosen canonical repo using the active agent's system skill authoring workflow. Target the chosen repo as the output directory and include agent-specific metadata only when that agent requires it.

4. Edit only files under the canonical skill directory.
5. Create discovery symlinks. For agent-neutral skills (personal repo, and private-registry repos unless their entry says otherwise):

```sh
mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills"
ln -s "<chosen-repo>/<skill-name>" "$HOME/.agents/skills/<skill-name>"
ln -s "<chosen-repo>/<skill-name>" "$HOME/.claude/skills/<skill-name>"
```

For Claude Code-only skills (cc-skills), create only the Claude link:

```sh
mkdir -p "$HOME/.claude/skills"
ln -s "$HOME/ghq/github.com/maguroid/cc-skills/<skill-name>" "$HOME/.claude/skills/<skill-name>"
```

For Codex-only skills (codex-skills), create only the Codex link:

```sh
mkdir -p "$HOME/.codex/skills"
ln -s "$HOME/ghq/github.com/maguroid/codex-skills/<skill-name>" "$HOME/.codex/skills/<skill-name>"
```

6. Validate the symlinked skill using the active agent's system validation workflow. Validate through `$HOME/.agents/skills/<skill-name>` and, when supported, also check `$HOME/.claude/skills/<skill-name>`. For cc-skills, validate through `$HOME/.claude/skills/<skill-name>` only. For codex-skills, validate through `$HOME/.codex/skills/<skill-name>` only.

## Updating An Existing Global Skill

1. Resolve the canonical path:

```sh
readlink "$HOME/.agents/skills/<skill-name>"
```

If there is no entry in `$HOME/.agents/skills`, also check `readlink "$HOME/.claude/skills/<skill-name>"` and `readlink "$HOME/.codex/skills/<skill-name>"`. A skill that resolves only from one harness-specific directory into its matching canonical repo is valid, not a defect.

2. If it points into a canonical repo (`maguroid/skills`, `maguroid/cc-skills`, `maguroid/codex-skills`, or a repo listed in `$HOME/.agents/skills-repos.local.md`), edit that canonical directory and commit & push in that repo.
3. If it is a real directory in a discovery directory, migrate it to the appropriate canonical repo first.
4. If it is a broken symlink, inspect before replacing it.
5. Ensure the discovery links match the repo's scheme: agent-neutral → `$HOME/.agents/skills` and `$HOME/.claude/skills`; cc-skills → `$HOME/.claude/skills` only; codex-skills → `$HOME/.codex/skills` only. Remove stale links from directories outside the selected scheme.
6. Validate through the selected scheme's discovery link after edits.

## Migration Workflow

When migrating an existing user-created global skill:

1. Copy the real skill directory into the canonical repo with `rsync -a`.
2. Confirm the canonical copy has `SKILL.md`.
3. Move the original directory to a temporary backup, such as `/private/tmp/skills-migration/<skill-name>`.
4. Create discovery symlinks according to the target repo's scheme.
5. Validate the symlinked skill.
6. Leave unrelated existing skills and symlinks untouched.

Do not migrate system skills.

## Sync Workflow

Use this when the user asks to sync skills from the remote repositories to this machine, e.g. after setting up a new machine or when another machine pushed new skills. `bootstrap.sh` now does both the pulling and the linking, so the default path is simply:

```sh
bash "$HOME/ghq/github.com/maguroid/skills/bootstrap.sh"
```

- It covers every registered repo (the three public repos plus registry entries), pulling each existing clean repo `--ff-only` and reconciling discovery symlinks per each repo's symlink scheme, with the semantics described in New Machine Bootstrap. Dirty working trees are warned and skipped — never stash or discard the user's changes; resolve them deliberately and re-run. Pull failures (e.g. a WIP branch with no upstream) are warning-only.
- It also rides the dotfiles apply chain: `chezmoi update` runs it via a `run_after` hook (1-hour throttle; `HARNESS_SYNC_FORCE=1` forces), and that hook pulls the `maguroid/skills` repo itself first so the script is never stale. So a plain `chezmoi update` usually syncs skills as a side effect — see the `harness-sync` skill for that chain.
- Read its Summary and report it: `pulled` / `pull skipped (dirty)` / `pull failures`, plus newly linked, repaired, already-correct, and conflicts skipped. Never silently overwrite a conflict; do not touch discovery entries that resolve to other repositories.

After a sync, validate a sample of the synced skills through the discovery directory selected by each repo's scheme using the active agent's validation workflow.

Workspace-local projections are a separate, non-global layer. After the workspace repositories are present, run `global-skill-workflow/scripts/reconcile_workspace_skills.sh`; the configured chezmoi hub-sync chain normally does this automatically. Do not link these skills into `$HOME/.agents/skills`, because workspace-specific names such as `tasks` or `daily-task` can legitimately have different behavior in different roots.

## Auto Push (Claude Code Stop hook)

The push direction is automated for the **three built-in public repos only** (`maguroid/skills`, `maguroid/cc-skills`, `maguroid/codex-skills`), mirroring the hub-repo auto-sync model (introduced 2026-07-06):

- The user's global Claude Code settings run `global-skill-workflow/scripts/auto_sync.sh` on every Stop. When a target repo is dirty on `main`, it commits everything (`chore: スキル自動同期 (日時)`) and pushes; unpushed commits from earlier blocked pushes are also retried. Clean repos are a no-op.
- Registry repos (`$HOME/.agents/skills-repos.local.md`) are **deliberately excluded**: they are team-shared repos or ordinary projects that contain more than skills, so whole-repo auto-commit is wrong there — commit those manually.
- The secret gate is each repo's lefthook + secretlint pre-push hook (all built-in repos are wired). A blocked push leaves the commit local and surfaces a `systemMessage`; repair per the recovery flow in `harness-sync` (same semantics as the dotfiles repo).
- Consequence for agents: after editing a skill in a built-in repo you may still commit deliberately with a descriptive message (preferred) — the hook only sweeps up what's left. On non-`main` branches the hook does nothing.

## Git Hygiene

Before and after changes, check the canonical repo you touched:

```sh
git -C "<chosen-repo>" status --short --branch
```

Do not revert pre-existing changes in the canonical repo. Report unrelated dirty state separately from the skill you created or updated.

## Validation Checklist

- `SKILL.md` exists in the canonical skill directory.
- The skill has links only in its scheme's discovery directories: agent-neutral → `$HOME/.agents/skills` and `$HOME/.claude/skills`; Claude Code-only → `$HOME/.claude/skills`; Codex-only → `$HOME/.codex/skills`.
- No stale link to that canonical skill remains in a discovery directory outside its scheme.
- The active agent's skill validator passes for the symlinked skill.
- Agent-specific metadata files are present and valid only when required by that agent.
- No machine-specific absolute home paths remain in authored skill files; use `$HOME`-relative paths for discovery and canonical directories.
- Workspace-scoped skills have one real canonical directory under the owning workspace, and both discovery links at the actually opened root resolve to it.
- Workspace-local names are not leaked into global discovery directories.
