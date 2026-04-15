---
name: dbc-coder
description: "Implement or refactor code and tests with Design by Contract (DbC): derive preconditions, postconditions, invariants, and failure modes before writing code. Use when Codex needs to turn requirements, bug reports, or existing APIs into contract-driven implementation and tests, especially in TypeScript codebases. Read `references/languages/typescript.md` for TypeScript patterns and add future languages under `references/languages/`."
---

# DbC Coder

## Overview

Treat every change as a contract. Make preconditions, postconditions, invariants, and failure semantics explicit before editing code, then write tests that prove the contract instead of merely mirroring the implementation.

Stay abstract while the user is still discussing architecture, responsibilities, or module boundaries. Do not show the full contract template until the conversation reaches a concrete module, API, function group, or file-level implementation step.

## Workflow

1. Extract the contract before writing code.
2. Inspect the repository for existing validation, error, and test conventions.
3. Choose where each part of the contract should live.
4. Implement the smallest change that satisfies the contract.
5. Write tests mapped directly to the contract.
6. Run focused verification, then broader tests when the change touches shared behavior.

## Design Boundary

- During high-level design, discuss responsibilities, module boundaries, data flow, and tradeoffs without asking the user to review a full contract template.
- Switch to contract mode only when the work is concrete enough to name the module, API surface, or implementation unit that will be edited next.
- At that handoff point, summarize the contract to the user and confirm it before writing module-level code or tests.

## Contract Template

Use this compact template only when the task has reached module-level implementation or a similarly concrete editing step:

```text
Subject:
Preconditions:
- ...
Postconditions:
- ...
Invariants:
- ...
Failures:
- ...
```

If the request is underspecified, infer the narrowest contract that matches the existing codebase and state the assumption in the final response. If the work is still architectural, postpone this template and keep the discussion at the design level.

## Contract Mapping

- Put structural guarantees in types when the language and project style support it.
- Guard untrusted runtime input at module boundaries, API handlers, constructors, and public entrypoints.
- Check invariants at object construction and around state transitions.
- Reuse repository-native error types, assertion helpers, and validation utilities when they already exist.
- Avoid introducing a dedicated DbC library unless the repository already uses one or the user explicitly asks for it.

## Implementation Rules

- Keep each contract check close to the boundary that owns it instead of repeating the same precondition in many helpers.
- Fail loudly on contract violations. Do not silently coerce invalid input unless normalization is already part of the surrounding contract.
- Write error messages that identify which part of the contract failed.
- Centralize invariant checks for stateful objects so constructors and mutating methods share the same logic.
- Do not duplicate runtime checks for properties already guaranteed by local control flow or trusted typed callers.

## Testing Rules

Write tests from the contract:

- success cases proving the promised postconditions
- boundary cases at the edge of valid input
- contract violations showing invalid calls are rejected
- invariant-preservation cases across state changes
- regression coverage for the motivating bug, ticket, or scenario

When the project convention allows it, assert both that a failure occurs and why it occurs. For stateful code, verify returned values and resulting state.

## Language References

- TypeScript: read `references/languages/typescript.md`
- Future languages: add `references/languages/<language>.md` using `references/languages/language-template.md`, then list it here

## Output Expectations

When using this skill, produce:

1. For high-level design: a short design summary, open decisions, and the proposed module boundary.
2. For module-level implementation: a short contract summary confirmed with the user.
3. The implementation or refactor.
4. Tests mapped to the contract.
5. A brief verification note with commands run and any remaining assumptions.
