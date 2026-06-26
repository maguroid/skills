# Getting the real SDK types (the source of truth)

This skill deliberately does **not** bundle the SDK's type definitions — the
package releases often and a vendored copy would go stale. Instead, fetch the
types for the exact version that matters and grep those.

The full public API ships as `.d.ts` files **inside the npm package**, not in the
GitHub repo (the repo is a thin wrapper). The two files you'll want:

- `sdk.d.ts` — the public API: `query`, `tool`, `createSdkMcpServer`, `Options`,
  the `SDKMessage` union, hooks, permissions, sessions, the `Query` interface.
- `sdk-tools.d.ts` — input/output schemas for the built-in tools (Bash, Read,
  Edit, Write, Glob, Grep, WebFetch, …).

## Which version to fetch

The authoritative version depends on where the code runs:

1. **Working inside a project that has the SDK installed** → that project's
   installed copy is the truth (it's what the code compiles against).
2. **Greenfield / advice / no install** → use the latest published version, and
   confirm with the user if a specific version is pinned.

## Fastest path: the helper

`scripts/find-sdk-types.sh` resolves a usable `sdk.d.ts` for you — it returns the
project's installed copy if present, otherwise downloads the requested version
(default: latest) into a local cache and returns that path.

```sh
DTS=$(scripts/find-sdk-types.sh)            # installed copy, else latest
DTS=$(scripts/find-sdk-types.sh 0.4.12)     # a specific version
TOOLS=$(scripts/find-sdk-types.sh --tools)  # sdk-tools.d.ts instead

grep -n "permissionMode" "$DTS"
sed -n '/export declare type Options = {/,/^};/p' "$DTS"
```

Every grep example in this skill's reference files assumes you've resolved `$DTS`
(and `$TOOLS`) once this way.

## Manual paths (when you'd rather not use the helper)

**Installed in a project:**
```sh
ls node_modules/@anthropic-ai/claude-agent-sdk/sdk.d.ts
# (walk up if you're in a subdir of the project)
```

**Fetch a version directly from npm (no install):**
```sh
cd "$(mktemp -d)"
npm pack @anthropic-ai/claude-agent-sdk            # add @<version> to pin
tar -xzf anthropic-ai-claude-agent-sdk-*.tgz
ls package/sdk.d.ts package/sdk-tools.d.ts
```

**Check versions:**
```sh
npm view @anthropic-ai/claude-agent-sdk version    # latest published
node -p "require('@anthropic-ai/claude-agent-sdk/package.json').version"  # installed, from a project
```

## Official docs

- Overview: https://docs.claude.com/en/api/agent-sdk/overview
- TypeScript SDK reference: https://docs.claude.com/en/api/agent-sdk/typescript
- Migration (Claude Code SDK → Agent SDK): https://docs.claude.com/en/docs/claude-code/sdk/migration-guide
- Repo: https://github.com/anthropics/claude-agent-sdk-typescript

## What's version-stable vs. not

- **Durable (trust this skill's prose):** the mental model, the gotchas, the
  workflow shape, the recipes. These rarely change between releases.
- **Version-specific (verify against the fetched `.d.ts`):** exact field names,
  enum members, and especially **defaults** (e.g. `systemPrompt` /
  `settingSources` behavior). Don't assert these from memory — grep the types.
