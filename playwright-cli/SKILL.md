---
name: playwright-cli
description: "Automate browser interactions and develop or debug Playwright tests through playwright-cli."
allowed-tools: Bash(playwright-cli:*) Bash(npx:*) Bash(npm:*)
---

# Browser Automation with playwright-cli

Use the CLI for browser interactions and Playwright test work when that is the selected browser-control surface.
Respect an explicitly selected browser and the active environment's browser tooling rules.

Start with a task-specific named session; observe the page, interact using fresh snapshot refs,
then inspect the resulting state. A successful command alone does not establish that the task succeeded.

```bash
playwright-cli -s=<task> open https://example.com
playwright-cli -s=<task> snapshot
playwright-cli -s=<task> click <ref-from-snapshot>
playwright-cli -s=<task> snapshot
```

Use screenshots when appearance matters and snapshots for text, controls, and state.
Keep existing authorization boundaries for submissions, accounts, and external changes.
Close only sessions created for this task; do not use `close-all` or `kill-all` as routine cleanup.

Read [commands.md](references/commands.md) for specific command syntax, browser/profile selection,
installation, output formats, or annotation mode. Installation follows this environment's tool-management policy.
Do not require annotation/user review for ordinary browser work.

## Specific tasks

* **Running and Debugging Playwright tests** [references/playwright-tests.md](references/playwright-tests.md)
* **Request mocking** [references/request-mocking.md](references/request-mocking.md)
* **Running Playwright code** [references/running-code.md](references/running-code.md)
* **Browser session management** [references/session-management.md](references/session-management.md)
* **Spec-driven testing (plan / generate / heal)** [references/spec-driven-testing.md](references/spec-driven-testing.md)
* **Storage state (cookies, localStorage)** [references/storage-state.md](references/storage-state.md)
* **Test generation** [references/test-generation.md](references/test-generation.md)
* **Tracing** [references/tracing.md](references/tracing.md)
* **Video recording** [references/video-recording.md](references/video-recording.md)
* **Inspecting element attributes** [references/element-attributes.md](references/element-attributes.md)
