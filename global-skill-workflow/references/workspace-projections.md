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
