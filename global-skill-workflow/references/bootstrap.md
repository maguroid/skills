## New Machine Bootstrap

Use `$HOME/ghq/github.com/maguroid/skills/bootstrap.sh` when setting up global skills on a new terminal or machine. The script is idempotent and uses only `$HOME`-relative paths. It always knows the three public canonical repos (`maguroid/skills` as agent-neutral, `maguroid/cc-skills` as Claude Code-only, and `maguroid/codex-skills` as Codex-only), and if `$HOME/.agents/skills-repos.local.md` exists, it reads the additional repo entries declared there. When a chezmoi source copy exists at `$HOME/.local/share/chezmoi/dot_agents/skills-repos.local.md`, the script reads that too and de-duplicates entries by path; this lets the source registry be tested before applying it. The registry is machine-local/private data; this public repo must mention only the registry format and never private organization names, repository names, or audiences.

Registry entries use `- Path: \`...\``, `- GitHub: \`owner/repo\``, and `- Symlink scheme: ...`; supported schemes are `agent-neutral`, `claude-only`, `codex-only`, and `workspace-only`. They may also include `- Skills path: \`<subdir>\``. When `Skills path` is omitted, the repo is treated like the personal repo: top-level directories containing `SKILL.md` are skills. When it is `skills`, top-level directories under that subdirectory are skills. When it is `.`, the repository root itself is one skill, and the link name is the repository directory name. Every `workspace-only` entry must also have a matching `Skills` entry in `$HOME/.agents/workspace-skills.local.md`; this keeps clone/pull automation while delegating discovery to the workspace projection layer.

The bootstrap script clones any missing canonical repo with its SSH GitHub URL. For repos that already exist, it also pulls: clean working tree → `git pull --ff-only`; dirty → warn and skip; pull failure (e.g. a WIP branch with no upstream) → warning only, the run continues. The Summary reports `pulled`, `pull skipped (dirty)`, and `pull failures` alongside the link counts. Clone failures for the three built-in public repos are fatal; clone failures for registry repos are warning-only so private or optional repos do not make chezmoi hooks fail forever on machines without access.

After clone-and-pull, the script reconciles discovery symlinks: create missing symlinks, repair broken symlinks whose intended target is the canonical skill directory, leave already-correct links untouched, and report real directories or foreign symlinks as conflicts without overwriting them. Agent-neutral repos link each top-level `SKILL.md` directory into both `$HOME/.agents/skills` and `$HOME/.claude/skills`. Claude Code-only repos link into `$HOME/.claude/skills` only. Codex-only repos link into `$HOME/.codex/skills` only. Workspace-only repos create no home-global links. Matching links in a discovery directory outside the repo's scheme are reported as strays and left untouched.

Run `bootstrap.sh` manually on each machine. Since 2026-10-18 nothing runs it automatically (the dotfiles apply chain and cross-machine auto-sync were retired). The private registry `$HOME/.agents/skills-repos.local.md` is maintained per machine; keep its contents out of this public skill repo.


## Sync Workflow

Use this when the user asks to sync skills from the remote repositories to this machine, e.g. after setting up a new machine or when another machine pushed new skills. `bootstrap.sh` now does both the pulling and the linking, so the default path is simply:

```sh
bash "$HOME/ghq/github.com/maguroid/skills/bootstrap.sh"
```

- It covers every registered repo (the three public repos plus registry entries), pulling each existing clean repo `--ff-only` and reconciling discovery symlinks per each repo's symlink scheme, with the semantics described in New Machine Bootstrap. Dirty working trees are warned and skipped — never stash or discard the user's changes; resolve them deliberately and re-run. Pull failures (e.g. a WIP branch with no upstream) are warning-only.
- Read its Summary and report it: `pulled` / `pull skipped (dirty)` / `pull failures`, plus newly linked, repaired, already-correct, and conflicts skipped. Never silently overwrite a conflict; do not touch discovery entries that resolve to other repositories.

After a sync, validate a sample of the synced skills through the discovery directory selected by each repo's scheme using the active agent's validation workflow.

Workspace-local projections are a separate, non-global layer. After the workspace repositories are present, run `global-skill-workflow/scripts/reconcile_workspace_skills.sh`. Do not link these skills into `$HOME/.agents/skills`, because workspace-specific names such as `tasks` or `daily-task` can legitimately have different behavior in different roots.

## Commit and Push

There is no auto-push hook (the Stop-hook auto-sync was retired on 2026-10-18). After editing a skill, commit deliberately with a descriptive message and push following the active approval policy. Each repo's lefthook + secretlint pre-push hook remains the secret gate; a blocked push leaves the commit local — remove the secret, amend or soft-reset the local commit, and push again.
