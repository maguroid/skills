---
name: harness-sync
description: "Edit chezmoi-managed dotfiles, sync Macs, or diagnose environment drift. Also handles Codex CLI, Hammerspoon, Tailscale, and Wrangler setup."
---

# Harness Sync

Maintain this user's chezmoi-managed environment. Select the operation before loading its procedures.

## Route by task

- Editing a dotfile or reconciling local drift: first run `chezmoi source-path <target>`.
  If managed, read [push.md](references/push.md), edit its source, preview and apply only the affected targets.
  An unmanaged file stays unmanaged unless the user asks to add it.
- New Mac, daily synchronization, doctor findings, or sync conflicts: read [pull.md](references/pull.md).
- Hook ordering, registries, or which mechanism owns a component: read [sync-architecture.md](references/sync-architecture.md).
- Standalone Codex CLI installation/update: read [codex-cli.md](references/codex-cli.md).
- Tailscale OSS daemon or MagicDNS: read [tailscale-macos.md](references/tailscale-macos.md).
- X OAuth setup/repair: read [xurl-oauth.md](references/xurl-oauth.md).
- Skill placement, authoring, or discovery links: use `global-skill-workflow`.

## Invariants

- The chezmoi source is canonical. Review for secrets before changing source state;
  source-mutating chezmoi commands may auto-commit and auto-push immediately.
- Credentials, OAuth tokens, SSH keys, and machine state are never copied between Macs or committed.
- Preserve unrelated edits. Follower drift policy applies to a requested sync after inspecting the diff;
  it is not permission to discard work while editing an individual setting.
- Honor existing publication authorization. Direct source edits need deliberate commit/push;
  a sync procedure does not grant new publication permission.
- Run checks for the affected operation. A small prompt edit does not require full environment
  doctor, tool upgrades, login repair, or a full-tree apply. Exclude unrelated scripts when applying only text files.
- A sandbox network/authentication failure requires the same-command escalation retry before
  diagnosing credentials. Interactive authentication remains per-device.

Complete the requested edit/sync and verify its resulting state. Report actual changes,
publication status, and actionable remaining failures; do not treat unrelated doctor warnings as blockers.
