---
name: note
description: Manual-only workflow for turning a user note such as `/note Always respond in Japanese` or `/note -g Prefer concise replies` into durable, agent-neutral instructions in project or global AGENTS.md, CLAUDE.md, or similar coding-agent instruction files. Use only when explicitly invoked as `/note` or by name; do not trigger implicitly for ordinary preference statements.
---

# Agent Note Instructions

## Overview

Convert a short user note into a clear, durable instruction and write it into the appropriate agent instruction file while preserving the file's existing structure and tone.

Keep the resulting instruction usable by multiple coding agents. Avoid Codex-only wording unless the existing file is explicitly Codex-specific.

## Workflow

1. Parse scope and remove note command syntax.
   - Treat `/note ...` as a request to persist the note.
   - If the note includes `-g` or `--global`, use global scope and remove that flag from the instruction text.
   - Without `-g` or `--global`, use project scope.
   - If the user names a specific instruction file, respect that explicit target and still remove command flags from the instruction text.

2. Identify the target instruction file.
   - For project scope, prefer the current repository or workspace instruction file, usually `AGENTS.md`.
   - If the project uses another agent instruction file, such as `CLAUDE.md`, apply the same workflow there when that is the appropriate target.
   - For global scope, edit the active agent's global instruction file rather than the project file.
   - If global scope is requested but the global instruction path is unclear for the active agent, ask the user to identify the file before creating or editing one.

3. Read the full target file before editing.
   - Preserve existing sections, language, heading style, and formatting conventions.
   - Treat existing instructions as authoritative; do not remove or weaken them unless the user explicitly asks.

4. Reframe the note as an instruction.
   - Convert conversational text into imperative, durable guidance.
   - Make it specific enough to be actionable in future sessions.
   - Remove command syntax such as `/note`, `-g`, and `--global`.
   - Avoid references to the current chat unless the instruction truly depends on this context.

5. Choose placement by fit.
   - Add to an existing section when the note naturally belongs there.
   - Create a new concise section only when no existing section fits.
   - Keep related instructions together, especially language, response style, safety, tool usage, file editing, validation, and project workflow rules.

6. Edit narrowly.
   - Add the smallest text that preserves the user's intent.
   - Do not reformat unrelated content.
   - Do not add implementation history, examples, or rationale unless the file's existing style uses them.

7. Validate the result.
   - Re-read the edited area and nearby headings.
   - Check for duplicate or conflicting instructions.
   - If a conflict exists, surface it and either reconcile conservatively or ask the user before changing semantics.

## Rewriting Notes

Rewrite notes into agent-neutral rules:

- `/note 常に日本語で応答してください` -> `Respond in Japanese unless the user explicitly requests another language.`
- `/note -g 簡潔に回答してください` -> `Respond concisely unless the task requires detail.`
- `/note --global 作業前に関連ファイルを読んで` -> `Read relevant files before making changes.`
- `/note テストが落ちたら原因を調べてから修正して` -> `When tests fail, inspect the failure cause before changing code.`
- `/note gh がネットワークで失敗したら sandbox を疑って` -> `When network-backed CLI commands fail with connection, DNS, authentication, or API errors, consider sandbox restrictions before treating the error as a real service or credential failure.`

Prefer "the agent" or direct imperative phrasing over product names. Use "Codex" or "Claude Code" only when the instruction applies only to that product or the target file already uses product-specific terminology.

## Manual Triggering

This skill is manual-only. Use it only when the user explicitly invokes `/note` or otherwise asks to persist a note into agent instructions. Do not use it merely because the user states a one-off preference during normal work.
