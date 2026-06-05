---
name: global-skill-workflow
description: Create, update, migrate, or organize global Codex skills for maguroid. Use when Codex is asked to make a global skill, install a personal/global skill, update an existing global skill, move skills between discovery directories, or manage symlinks for skill discovery. This skill defines the canonical location `/Users/maguroid/ghq/github.com/maguroid/skills` and requires discoverable skills to be symlinked from `/Users/maguroid/.agents/skills`.
---

# Global Skill Workflow

## Core Rule

Use `/Users/maguroid/ghq/github.com/maguroid/skills` as the canonical source for user-created global skills. Make `/Users/maguroid/.agents/skills/<skill-name>` a symlink to the canonical skill directory. Do not create or maintain user-created skill symlinks in `/Users/maguroid/.codex/skills`; Codex discovers global skills from `/Users/maguroid/.agents/skills`.

Use this skill with `skill-creator` when authoring or updating the skill content. This skill controls placement, linking, migration, and validation.

## Paths

- Canonical repo: `/Users/maguroid/ghq/github.com/maguroid/skills`
- Discovery directory: `/Users/maguroid/.agents/skills`
- Do not use for user-created global skills: `/Users/maguroid/.codex/skills`
- Do not modify system skills: `/Users/maguroid/.codex/skills/.system`

## New Global Skill Workflow

1. Choose a hyphen-case skill name under 64 characters.
2. Confirm the canonical path does not already exist:

```sh
test -e /Users/maguroid/ghq/github.com/maguroid/skills/<skill-name>
```

3. Initialize the skill in the canonical repo:

```sh
python3 /Users/maguroid/.codex/skills/.system/skill-creator/scripts/init_skill.py <skill-name> \
  --path /Users/maguroid/ghq/github.com/maguroid/skills \
  --interface display_name="..." \
  --interface short_description="..." \
  --interface default_prompt='Use $<skill-name> ...'
```

4. Edit only files under the canonical skill directory.
5. Create the discovery symlink:

```sh
ln -s /Users/maguroid/ghq/github.com/maguroid/skills/<skill-name> \
  /Users/maguroid/.agents/skills/<skill-name>
```

6. Validate the symlinked skill:

```sh
python3 /Users/maguroid/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  /Users/maguroid/.agents/skills/<skill-name>
```

If the active Python lacks PyYAML, use another Python environment with PyYAML or a local shim only for the validator.

## Updating An Existing Global Skill

1. Resolve the canonical path:

```sh
readlink /Users/maguroid/.agents/skills/<skill-name>
```

2. If it points to `/Users/maguroid/ghq/github.com/maguroid/skills/<skill-name>`, edit the canonical directory.
3. If it is a real directory in `/Users/maguroid/.agents/skills`, migrate it to the canonical repo first.
4. If it is a broken symlink, inspect before replacing it.
5. Validate through `/Users/maguroid/.agents/skills/<skill-name>` after edits.

## Migration Workflow

When migrating an existing user-created global skill:

1. Copy the real skill directory into the canonical repo with `rsync -a`.
2. Confirm the canonical copy has `SKILL.md`.
3. Move the original directory to a temporary backup, such as `/private/tmp/maguroid-skills-migration/<skill-name>`.
4. Create `/Users/maguroid/.agents/skills/<skill-name>` as a symlink to the canonical copy.
5. Validate the symlinked skill.
6. Leave unrelated existing skills and symlinks untouched.

Do not migrate `/Users/maguroid/.codex/skills/.system`.

## Git Hygiene

Before and after changes, check:

```sh
git -C /Users/maguroid/ghq/github.com/maguroid/skills status --short --branch
```

Do not revert pre-existing changes in the canonical repo. Report unrelated dirty state separately from the skill you created or updated.

## Validation Checklist

- `SKILL.md` exists in the canonical skill directory.
- `/Users/maguroid/.agents/skills/<skill-name>` is a symlink to the canonical directory.
- No user-created symlink was added under `/Users/maguroid/.codex/skills`.
- `quick_validate.py` passes for the symlinked skill.
- `agents/openai.yaml` uses a quoted `default_prompt` containing `$<skill-name>` when present.
- No placeholder text remains in authored skill files.
