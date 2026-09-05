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
5. Ensure the discovery links match the repo's scheme: agent-neutral → `$HOME/.agents/skills` and `$HOME/.claude/skills`; cc-skills → `$HOME/.claude/skills` only; codex-skills → `$HOME/.codex/skills` only; workspace-only → no home-global link, with root-local links managed through the workspace projection registry. Remove stale links from directories outside the selected scheme.
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
