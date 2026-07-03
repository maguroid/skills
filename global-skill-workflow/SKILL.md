---
name: global-skill-workflow
description: Create, update, migrate, sync, or organize global skills. Use when an agent is asked to make a global skill, install a personal/global skill, update an existing global skill, sync skills from the remote repository to the local machine, move skills between discovery directories, or manage symlinks for skill discovery. Canonical repos are `$HOME/ghq/github.com/maguroid/skills` (personal, default) and `$HOME/ghq/github.com/maguroid/cc-skills` (Claude Code-only), plus any private repos registered in the local registry `$HOME/.agents/skills-repos.local.md`; discovery symlinks live in `$HOME/.agents/skills` and `$HOME/.claude/skills`.
---

# Global Skill Workflow

## Core Rule

Use `$HOME/ghq/github.com/maguroid/skills` as the canonical source for user-created global skills. Make both `$HOME/.agents/skills/<skill-name>` and `$HOME/.claude/skills/<skill-name>` symlinks to each canonical skill directory.

Use the active agent's system skill authoring and validation workflow when creating or updating skill content. This skill controls placement, linking, migration, and validation targets.

## Choosing the Canonical Repo

Two public canonical repos exist, plus optional private repos in a local registry. Choose by audience and harness before creating or migrating a skill:

- **Personal skills** (the user's own tooling, machine setup, personal workflows; agent-neutral): `$HOME/ghq/github.com/maguroid/skills` (default; public).
- **Claude Code-only skills** (skills that only make sense inside the Claude Code harness — e.g. they orchestrate Claude Code-specific delegation or tooling, like `codex-delegate`): `$HOME/ghq/github.com/maguroid/cc-skills` (GitHub: `maguroid/cc-skills`; public).
- **Additional repos (including private repos)**: registered in the machine-local registry `$HOME/.agents/skills-repos.local.md`. **Read that file before choosing a repo** — if the skill's audience matches an entry there, use that repo. This SKILL.md lives in a public repo, so private repo names, org names, and audience details belong ONLY in the registry file, never here. When creating or updating a skill in an additional repo, keep following this workflow's steps with that repo's path, skills path, and symlink scheme as declared by its registry entry.

Symlink scheme by repo:

- Personal skills — and private-registry repos unless their entry says otherwise — link into **both** `$HOME/.agents/skills` and `$HOME/.claude/skills`.
- Claude Code-only skills (cc-skills) link into **`$HOME/.claude/skills` only** — never into `$HOME/.agents/skills`, which is the agent-neutral discovery directory read by other harnesses (codex etc.).

The sync workflow below applies to the personal repo; for cc-skills and registry repos, sync is a plain `git pull` (symlinks resolve to the pulled working tree) plus creating symlinks for any newly added skills, per each repo's symlink scheme and skills path. When a skill's audience or harness scope changes, move it between repos: copy to the target repo, commit both repos, and repoint the discovery symlinks with `ln -sfn` (when a skill moves out of cc-skills to an agent-neutral repo, add the missing `$HOME/.agents/skills` link; when it moves into cc-skills, remove that link).

## Paths

- Canonical repos: `$HOME/ghq/github.com/maguroid/skills` (personal, default) / `$HOME/ghq/github.com/maguroid/cc-skills` (Claude Code-only) / private repos per `$HOME/.agents/skills-repos.local.md`
- Active agent discovery directory (agent-neutral): `$HOME/.agents/skills`
- Claude discovery directory: `$HOME/.claude/skills`
- Skill authoring and validation tools: use the active agent's system skills or built-in skill tooling.

Use `$HOME` rather than an OS-user-specific absolute home path in skill instructions. Do not use a non-hidden `$HOME/claude/skills` directory unless the user explicitly configures or requests that alternate location.

## New Machine Bootstrap

Use `$HOME/ghq/github.com/maguroid/skills/bootstrap.sh` when setting up global skills on a new terminal or machine. The script is idempotent and uses only `$HOME`-relative paths. It always knows the two public canonical repos (`maguroid/skills` as agent-neutral and `maguroid/cc-skills` as Claude Code-only), and if `$HOME/.agents/skills-repos.local.md` exists, it reads the additional repo entries declared there. When a chezmoi source copy exists at `$HOME/.local/share/chezmoi/dot_agents/skills-repos.local.md`, the script reads that too and de-duplicates entries by path; this lets the source registry be tested before applying it. The registry is machine-local/private data; this public repo must mention only the registry format and never private organization names, repository names, or audiences.

Registry entries use `- Path: \`...\``, `- GitHub: \`owner/repo\``, and `- Symlink scheme: ...`; they may also include `- Skills path: \`<subdir>\``. When `Skills path` is omitted, the repo is treated like the personal repo: top-level directories containing `SKILL.md` are skills. When it is `skills`, top-level directories under that subdirectory are skills. When it is `.`, the repository root itself is one skill, and the link name is the repository directory name.

The bootstrap script clones any missing canonical repo with its SSH GitHub URL and leaves existing repos alone. It does not pull existing repos; pulling remains the responsibility of the Sync Workflow below so dirty working trees are handled deliberately. Clone failures for the two built-in public repos are fatal; clone failures for registry repos are warning-only so private or optional repos do not make chezmoi run-once hooks fail forever on machines without access.

After clone-if-missing, the script reconciles discovery symlinks with the same semantics as Sync Workflow step 4: create missing symlinks, repair broken symlinks whose intended target is the canonical skill directory, leave already-correct links untouched, and report real directories or foreign symlinks as conflicts without overwriting them. Agent-neutral repos link each top-level `SKILL.md` directory into both `$HOME/.agents/skills` and `$HOME/.claude/skills`. Claude Code-only repos link into `$HOME/.claude/skills` only; any matching link from `$HOME/.agents/skills` to a Claude Code-only skill is reported as a stray and left untouched.

The user's private dotfiles repo may distribute `$HOME/.agents/skills-repos.local.md` and a chezmoi `run_once_after_bootstrap-global-skills.sh` script. With that setup, `chezmoi init --apply` can install the private registry, clone `maguroid/skills` if needed, and run `bootstrap.sh` automatically. Keep private registry contents in the private dotfiles repo only, never in this public skill repo.

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

6. Validate the symlinked skill using the active agent's system validation workflow. Validate through `$HOME/.agents/skills/<skill-name>` and, when supported, also check `$HOME/.claude/skills/<skill-name>`. For cc-skills, validate through `$HOME/.claude/skills/<skill-name>` only.

## Updating An Existing Global Skill

1. Resolve the canonical path:

```sh
readlink "$HOME/.agents/skills/<skill-name>"
```

If there is no entry in `$HOME/.agents/skills`, also check `readlink "$HOME/.claude/skills/<skill-name>"` — a skill that resolves only from there into the cc-skills repo is a Claude Code-only skill, which is a valid state, not a defect.

2. If it points into a canonical repo (`maguroid/skills`, `maguroid/cc-skills`, or a repo listed in `$HOME/.agents/skills-repos.local.md`), edit that canonical directory and commit & push in that repo.
3. If it is a real directory in a discovery directory, migrate it to the appropriate canonical repo first.
4. If it is a broken symlink, inspect before replacing it.
5. Ensure the discovery links match the repo's scheme: both directories for agent-neutral repos; `$HOME/.claude/skills` only for cc-skills (remove a stray `$HOME/.agents/skills` link pointing into cc-skills).
6. Validate through `$HOME/.agents/skills/<skill-name>` after edits (`$HOME/.claude/skills/<skill-name>` for cc-skills).

## Migration Workflow

When migrating an existing user-created global skill:

1. Copy the real skill directory into the canonical repo with `rsync -a`.
2. Confirm the canonical copy has `SKILL.md`.
3. Move the original directory to a temporary backup, such as `/private/tmp/skills-migration/<skill-name>`.
4. Create `$HOME/.agents/skills/<skill-name>` and `$HOME/.claude/skills/<skill-name>` as symlinks to the canonical copy.
5. Validate the symlinked skill.
6. Leave unrelated existing skills and symlinks untouched.

Do not migrate system skills.

## Sync Workflow

Use this when the user asks to sync skills from the remote repository to this machine, e.g. after setting up a new machine or when another machine pushed new skills. The goal: pull the latest canonical repo from `origin`, then ensure every canonical skill is symlinked into both discovery directories.

This detailed procedure targets the **personal** repo. For cc-skills and private-registry repos, apply the same pattern with their path and symlink scheme (cc-skills reconciles `$HOME/.claude/skills` only; a full sync covers the two public repos plus every registry entry).

Scope is the canonical repo being synced. Do not touch discovery entries that resolve to other repositories.

1. Check for uncommitted changes before pulling:

```sh
git -C "$HOME/ghq/github.com/maguroid/skills" status --short --branch
```

If the working tree is dirty, report it and ask before pulling. Do not stash or discard the user's changes.

2. Pull from `origin` explicitly (the repo also has a `lima` remote; do not rely on the implicit upstream):

```sh
git -C "$HOME/ghq/github.com/maguroid/skills" pull origin "$(git -C "$HOME/ghq/github.com/maguroid/skills" branch --show-current)"
```

3. Enumerate canonical skills: every top-level directory in the canonical repo that contains a `SKILL.md`. Skip `.git` and any directory without `SKILL.md`.

4. For each canonical skill `<name>`, reconcile both `$HOME/.agents/skills/<name>` and `$HOME/.claude/skills/<name>`:
   - Missing: create the symlink to the canonical directory.
   - Symlink already pointing at the canonical directory: leave it.
   - Broken symlink whose intended target is the canonical directory: recreate it.
   - A real directory, or a symlink resolving to a different repository: do not overwrite. Report it as a conflict and leave it untouched.

```sh
mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills"
canonical="$HOME/ghq/github.com/maguroid/skills/<name>"
for dir in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  link="$dir/<name>"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$canonical" ]; then
    continue                      # already correct
  elif [ -e "$link" ] || { [ -L "$link" ] && [ "$(readlink "$link")" != "$canonical" ]; }; then
    echo "conflict: $link (left untouched)"   # real dir or foreign symlink
  else
    ln -sfn "$canonical" "$link"  # missing or broken canonical-target link
  fi
done
```

5. Report a summary: newly linked, already correct, repaired, and conflicts skipped. Never silently overwrite a conflict.

6. Validate a sample of the synced skills through `$HOME/.agents/skills/<name>` using the active agent's validation workflow.

## Git Hygiene

Before and after changes, check the canonical repo you touched:

```sh
git -C "<chosen-repo>" status --short --branch
```

Do not revert pre-existing changes in the canonical repo. Report unrelated dirty state separately from the skill you created or updated.

## Validation Checklist

- `SKILL.md` exists in the canonical skill directory.
- `$HOME/.agents/skills/<skill-name>` is a symlink to the canonical directory (**skip for cc-skills**: Claude Code-only skills must NOT appear in `$HOME/.agents/skills`).
- `$HOME/.claude/skills/<skill-name>` is a symlink to the canonical directory.
- The active agent's skill validator passes for the symlinked skill.
- Agent-specific metadata files are present and valid only when required by that agent.
- No machine-specific absolute home paths remain in authored skill files; use `$HOME`-relative paths for discovery and canonical directories.
