---
name: global-skill-workflow
description: Create, update, migrate, sync, or organize global skills. Use when an agent is asked to make a global skill, install a personal/global skill, update an existing global skill, sync skills from the remote repository to the local machine, move skills between discovery directories, or manage symlinks for skill discovery. This skill uses `$HOME/ghq/github.com/maguroid/skills` as the canonical repository and symlinks from `$HOME/.agents/skills` and `$HOME/.claude/skills`.
---

# Global Skill Workflow

## Core Rule

Use `$HOME/ghq/github.com/maguroid/skills` as the canonical source for user-created global skills. Make both `$HOME/.agents/skills/<skill-name>` and `$HOME/.claude/skills/<skill-name>` symlinks to each canonical skill directory.

Use the active agent's system skill authoring and validation workflow when creating or updating skill content. This skill controls placement, linking, migration, and validation targets.

## Personal vs Company Skills

Two canonical repos exist. Choose by audience before creating or migrating a skill:

- **Personal skills** (the user's own tooling, machine setup, personal workflows): `$HOME/ghq/github.com/maguroid/skills` (default).
- **Company skills** (Hashigodaka team-shared workflows, e.g. `hashigodaka-wiki`): `$HOME/ghq/github.com/pao-tech-labs/hashigodaka-skills` (GitHub: `pao-tech-labs/hashigodaka-skills`, private).

Both use the same symlink scheme into `$HOME/.agents/skills` and `$HOME/.claude/skills`. The sync workflow below applies to the personal repo; for the company repo, sync is a plain `git pull` (symlinks resolve to the pulled working tree) plus creating symlinks for any newly added skills. When a skill's audience changes, move it between repos: copy to the target repo, commit both repos, and repoint the discovery symlinks with `ln -sfn`.

## Paths

- Canonical repo: `$HOME/ghq/github.com/maguroid/skills`
- Active agent discovery directory: `$HOME/.agents/skills`
- Claude discovery directory: `$HOME/.claude/skills`
- Skill authoring and validation tools: use the active agent's system skills or built-in skill tooling.

Use `$HOME` rather than an OS-user-specific absolute home path in skill instructions. Do not use a non-hidden `$HOME/claude/skills` directory unless the user explicitly configures or requests that alternate location.

## New Global Skill Workflow

1. Choose a hyphen-case skill name under 64 characters.
2. Confirm the canonical path does not already exist:

```sh
test -e "$HOME/ghq/github.com/maguroid/skills/<skill-name>"
```

3. Initialize the skill in the canonical repo using the active agent's system skill authoring workflow. Target `$HOME/ghq/github.com/maguroid/skills` as the output directory and include agent-specific metadata only when that agent requires it.

4. Edit only files under the canonical skill directory.
5. Create discovery symlinks:

```sh
mkdir -p "$HOME/.agents/skills" "$HOME/.claude/skills"
ln -s "$HOME/ghq/github.com/maguroid/skills/<skill-name>" "$HOME/.agents/skills/<skill-name>"
ln -s "$HOME/ghq/github.com/maguroid/skills/<skill-name>" "$HOME/.claude/skills/<skill-name>"
```

6. Validate the symlinked skill using the active agent's system validation workflow. Validate through `$HOME/.agents/skills/<skill-name>` and, when supported, also check `$HOME/.claude/skills/<skill-name>`.

## Updating An Existing Global Skill

1. Resolve the canonical path:

```sh
readlink "$HOME/.agents/skills/<skill-name>"
```

2. If it points to `$HOME/ghq/github.com/maguroid/skills/<skill-name>`, edit the canonical directory.
3. If it is a real directory in `$HOME/.agents/skills`, migrate it to the canonical repo first.
4. If it is a broken symlink, inspect before replacing it.
5. Ensure `$HOME/.claude/skills/<skill-name>` also points to the canonical directory.
6. Validate through `$HOME/.agents/skills/<skill-name>` after edits.

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

Scope is the canonical repo only. Do not touch discovery entries that resolve to other repositories.

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

Before and after changes, check:

```sh
git -C "$HOME/ghq/github.com/maguroid/skills" status --short --branch
```

Do not revert pre-existing changes in the canonical repo. Report unrelated dirty state separately from the skill you created or updated.

## Validation Checklist

- `SKILL.md` exists in the canonical skill directory.
- `$HOME/.agents/skills/<skill-name>` is a symlink to the canonical directory.
- `$HOME/.claude/skills/<skill-name>` is a symlink to the canonical directory.
- The active agent's skill validator passes for the symlinked skill.
- Agent-specific metadata files are present and valid only when required by that agent.
- No machine-specific absolute home paths remain in authored skill files; use `$HOME`-relative paths for discovery and canonical directories.
