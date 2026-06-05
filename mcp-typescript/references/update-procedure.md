# MCP Information Update Procedure

Use this when the user asks to update, refresh, or latest-ize MCP information bundled with this skill.

## Policy

Track latest stable release tags, not moving branches.

- Do not bundle `main`.
- Do not bundle `draft`.
- Do not select RC, alpha, beta, canary, nightly, or package-scoped prerelease tags unless the user explicitly asks for prerelease information.
- Preserve TypeScript-only focus.

## Select Tags

Fetch tag information from GitHub:

```sh
git ls-remote --tags https://github.com/modelcontextprotocol/modelcontextprotocol.git
git ls-remote --tags https://github.com/modelcontextprotocol/typescript-sdk.git
```

For `modelcontextprotocol/modelcontextprotocol`, choose the latest date-like stable spec tag, for example `2025-11-25`. Exclude tags ending in `-RC` or otherwise marked as prerelease.

For `modelcontextprotocol/typescript-sdk`, choose the latest stable semver release tag. Prefer `vX.Y.Z` tags when present. Exclude `alpha`, `beta`, `rc`, and package-scoped prerelease tags such as `@modelcontextprotocol/server@2.0.0-alpha.2`.

## Investigate Version Risk

Before replacing bundled repositories, inspect the selected tags and summarize risks:

```sh
git -C /Users/maguroid/ghq/github.com/modelcontextprotocol/modelcontextprotocol fetch --tags --force
git -C /Users/maguroid/ghq/github.com/modelcontextprotocol/typescript-sdk fetch --tags --force
git -C /Users/maguroid/ghq/github.com/modelcontextprotocol/modelcontextprotocol checkout <spec-tag>
git -C /Users/maguroid/ghq/github.com/modelcontextprotocol/typescript-sdk checkout <sdk-tag>
```

Check:

- SDK major/version and package import shape.
- Whether the SDK tag is stable or prerelease.
- Which MCP protocol versions the SDK supports.
- README, `VERSIONING.md`, changelog/changesets, migration docs, and docs paths.
- Transport changes, especially Streamable HTTP, SSE compatibility, stdio behavior, sessions, resumability, and auth.
- Schema changes that affect tools, resources, prompts, capabilities, elicitation, sampling, roots, tasks, or output schemas.
- Runtime/dependency changes such as Node.js, Zod, Express, Hono, OAuth helpers, Web Crypto, or TypeScript requirements.

If the latest stable tags create an obvious mismatch, such as spec latest requiring a protocol version the latest stable SDK does not support, document the mismatch in `repository-map.md` and tell the user. Do not switch to prerelease tags without explicit user approval.

## Update Bundled Repositories

After selecting stable tags and reviewing risk, copy the checked-out ghq repositories into the skill. Exclude `.git` and delete stale files from prior bundles so old APIs do not remain discoverable:

```sh
rsync -a --delete --exclude .git \
  /Users/maguroid/ghq/github.com/modelcontextprotocol/modelcontextprotocol/ \
  /Users/maguroid/.codex/skills/mcp-typescript/references/repos/modelcontextprotocol/

rsync -a --delete --exclude .git \
  /Users/maguroid/ghq/github.com/modelcontextprotocol/typescript-sdk/ \
  /Users/maguroid/.codex/skills/mcp-typescript/references/repos/typescript-sdk/
```

## Update Skill References

Update `references/repository-map.md` with:

- Selected tags.
- Short commits.
- Whether tags are stable or prerelease.
- Any version risk that future agents must account for.
- Correct docs/examples paths for the selected SDK tag.

Update `references/typescript-sdk-patterns.md` if package names, imports, schema style, transport classes, error classes, or example paths changed.

Update `SKILL.md` only when trigger behavior, workflow, or resource navigation changes.

## Validate

Run the skill validator:

```sh
python3 /Users/maguroid/.codex/skills/.system/skill-creator/scripts/quick_validate.py /Users/maguroid/.codex/skills/mcp-typescript
```

If PyYAML is not installed in the active Python, use a Python environment that has it or provide an equivalent local shim for this validator only. Then confirm:

```sh
rg -n "TO[D]O|\\[TO[D]O|Use [-]typescript" /Users/maguroid/.codex/skills/mcp-typescript/SKILL.md /Users/maguroid/.codex/skills/mcp-typescript/references/*.md /Users/maguroid/.codex/skills/mcp-typescript/agents/openai.yaml
find /Users/maguroid/.codex/skills/mcp-typescript/references/repos -name .git -type d
```
