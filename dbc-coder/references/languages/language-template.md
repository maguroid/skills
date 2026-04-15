# Language Reference Template

Use this template when adding `references/languages/<language>.md`.

## Required Sections

Keep the same section order so the skill stays easy to extend:

1. `# <Language> Patterns`
2. `## Contract To Code`
3. `## Language Guidance`
4. `## Assertion Patterns`
5. `## Example: Stateful Contract`
6. `## Test Matrix`
7. `## Review Checklist`

## What To Capture

- How the language expresses preconditions, postconditions, and invariants
- Which built-in error or result patterns fit best
- How to validate external input at trust boundaries
- How to structure invariant checks for stateful objects
- How to test success, boundaries, and contract violations in the language's common test framework

## Example Expectations

- Prefer a small example that includes both a state transition and an invariant
- Keep examples framework-light unless a specific framework is dominant in the target ecosystem
- Reuse repository-native conventions where possible instead of forcing one DbC style everywhere
