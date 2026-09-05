---
name: global-skill-workflow
description: "Place, update, migrate, or sync personal/global skills and workspace discovery links in this environment."
---

# Global Skill Workflow

Edit the canonical skill, then verify its discovery links. Use the active harness's skill authoring/validation tools for content changes.

## Canonical locations

Read `$HOME/.agents/skills-repos.local.md` when selecting a repository; audience-specific entries take precedence.

| Scope | Repository under `$HOME/ghq/github.com/maguroid/` | Discovery |
|---|---|---|
| Personal, agent-neutral | `skills` | `$HOME/.agents/skills` and `$HOME/.claude/skills` |
| Claude Code-only | `cc-skills` | `$HOME/.claude/skills` only |
| Codex-only | `codex-skills` | `$HOME/.codex/skills` only |
| Workspace-only | Owning workspace's `.agents/skills` | Root-local links declared in `$HOME/.agents/workspace-skills.local.md` |

Keep private registry contents out of public repositories. Use `$HOME`-relative paths in authored instructions.

## Choose the work

- Existing skill edit: resolve its discovery symlink, inspect repository status, and edit the canonical directory.
  Validate the affected skill through the appropriate discovery link and check its references.
  No bootstrap or migration is needed when placement is already correct.
- New skill, migration, or a real directory in discovery: read [placement.md](references/placement.md).
- Parent-root discovery or duplicate workspace skills: read [workspace-projections.md](references/workspace-projections.md).
- Skill synchronization, machine bootstrap, or Stop-hook behavior: read [bootstrap.md](references/bootstrap.md).

## Content and completion

Keep descriptions short and discriminating: capability plus trigger; add an exclusion only for likely confusion.
Keep purpose, constraints, and routing in `SKILL.md`; load substantial mode-specific details on demand.
Preserve non-obvious operational invariants. Prefer outcomes and decision criteria to a fixed itinerary.
State the deliverable, meaningful validation, and where work must stop; an initial draft is not completion.

Check the touched repository before and after changes. Preserve pre-existing edits, metadata,
manual-only invocation policies, and links belonging to other repositories. Do not edit bundled system skills.
Validate relevant links and frontmatter; exercise scripts only if changed or their behavior is in question.
Commit the task's changes deliberately. Push only under existing user authorization; Stop-hook behavior
is documented separately and does not authorize a manual push to every repository.
