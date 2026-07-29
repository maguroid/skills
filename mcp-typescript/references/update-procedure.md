# MCP Information Update Procedure

Use this procedure when refreshing bundled MCP specification or TypeScript SDK information.

## Policy

Track only official stable releases. Do not use moving branches or prereleases.

- Never select `main`, `draft`, RC, alpha, beta, canary, nightly, or an unreleased commit as a snapshot source or canonical reference. A stable upstream snapshot can itself contain a historical `draft/` directory; retain it as upstream content if copied, but never navigate to or cite it as the canonical reference.
- Use `gh` CLI for GitHub release/tag information. Use `git` only for local repository/history inspection.
- Keep TypeScript-only focus.
- Preserve the current SDK major in an existing target project; a reference refresh does not authorize a user project's major upgrade.

## Select And Record Releases

List official releases before copying anything:

```sh
gh release list --repo modelcontextprotocol/modelcontextprotocol --limit 30
gh release list --repo modelcontextprotocol/typescript-sdk --limit 100
```

For the specification, choose the newest date-like stable release. For the SDK, inspect both the current v2 split-package releases and the latest v1 single-package release when compatibility coverage is retained. Package-scoped tags such as `@modelcontextprotocol/server@2.0.0` are valid **stable** v2 release tags; reject only their prerelease forms.

Clone official sources into a temporary directory and resolve commits locally:

```sh
tmp_dir=$(mktemp -d /private/tmp/mcp-skill-update.XXXXXX)
gh repo clone modelcontextprotocol/modelcontextprotocol "$tmp_dir/modelcontextprotocol" -- --depth 1 --branch <spec-tag>
gh repo clone modelcontextprotocol/typescript-sdk "$tmp_dir/typescript-sdk"
git -C "$tmp_dir/typescript-sdk" checkout '<v2-package-tag>'
git -C "$tmp_dir/typescript-sdk" rev-parse HEAD
git -C "$tmp_dir/typescript-sdk" worktree add --detach "$tmp_dir/typescript-sdk-v1" <v1-tag>
git -C "$tmp_dir/typescript-sdk-v1" rev-parse HEAD
```

Record in `repository-map.md`:

- exact stable tags and short commits;
- whether a tag is specification, v2 package/workspace, or v1 compatibility;
- package/import mapping and protocol-era compatibility;
- version risks and any unresolved mismatch.

## Investigate Version Risk

Read release notes, changelogs, migration docs, package manifests, docs paths, schema, and runnable examples before replacing snapshots. Explicitly check:

- SDK major/version, public package names, import shapes, Node/TypeScript/Zod requirements;
- supported MCP protocol versions and whether modern wire behavior is opt-in;
- transports, HTTP framework adapters, SSE compatibility, session headers, and resumability;
- tools/resources/prompts, capability negotiation, pagination, cancellation, and errors;
- `server/discover`, stateless per-request `_meta`, `resultType`, MRTR `input_required`, and `subscriptions/listen`;
- tasks/extensions, Roots/Sampling/Logging deprecations, caching metadata, HTTP headers, and authorization flow.

Do not hide a stable SDK/spec mismatch by selecting an RC, beta, or `main`. Document the mismatch and ask the user before changing coverage policy.

## Update Bundled Snapshots

Use generation-named directories and delete stale files within each destination. Keep no `.git` metadata:

```sh
rsync -a --delete --exclude .git \
  "$tmp_dir/modelcontextprotocol/" \
  "$HOME/ghq/github.com/maguroid/skills/mcp-typescript/references/repos/modelcontextprotocol/"

rsync -a --delete --exclude .git \
  "$tmp_dir/typescript-sdk/" \
  "$HOME/ghq/github.com/maguroid/skills/mcp-typescript/references/repos/typescript-sdk-v2/"

rsync -a --delete --exclude .git \
  "$tmp_dir/typescript-sdk-v1/" \
  "$HOME/ghq/github.com/maguroid/skills/mcp-typescript/references/repos/typescript-sdk-v1/"
```

Remove obsolete unversioned snapshot directories only after confirming the v1/v2 destinations exist. Do not leave old SDK APIs at a path that looks current.

## Update Skill References

- Keep `SKILL.md` concise and imperative. Point detailed facts to references.
- Make v2 the new-project default and v1 explicitly compatibility-only.
- State that v2 does not automatically select the 2026 wire: document `versionNegotiation`, `createMcpHandler`, and `serveStdio` as deliberate choices.
- Preserve the server-side HTTP framework selection/confirmation rule.
- Update `mcp-field-guide.md`, `typescript-sdk-patterns.md`, and `repository-map.md` together so package paths and protocol semantics agree.
- Compare `agents/openai.yaml` with `SKILL.md`; regenerate it only if its UI metadata no longer accurately describes the skill.
- Use `$HOME`, never a machine-specific home path, in authored instructions.

## Validate

Use the active agent's skill-authoring validator first, through the canonical directory and both required discovery links. Do not require a Codex-specific validator path from another harness.

For Codex, when the system `quick_validate.py` is the active validator, run it with an isolated PyYAML environment. This avoids assuming PyYAML is globally installed or writing a project environment:

```sh
skill_uv_cache=$(mktemp -d /private/tmp/mcp-skill-uv-cache.XXXXXX)
UV_CACHE_DIR="$skill_uv_cache" uv run --no-project --with pyyaml python \
  "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" \
  "$HOME/ghq/github.com/maguroid/skills/mcp-typescript"
UV_CACHE_DIR="$skill_uv_cache" uv run --no-project --with pyyaml python \
  "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" \
  "$HOME/.agents/skills/mcp-typescript"
UV_CACHE_DIR="$skill_uv_cache" uv run --no-project --with pyyaml python \
  "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" \
  "$HOME/.claude/skills/mcp-typescript"
```

Then verify references and stale assumptions:

```sh
find references/repos -name .git -type d
rg -n "2025-11-25|typescript-sdk/|@modelcontextprotocol/sdk/" SKILL.md references/*.md
rg -n "TO[D]O|\\[TO[D]O" SKILL.md references/*.md agents/openai.yaml
git diff --check
```

The v1 tag and `@modelcontextprotocol/sdk/...` references are intentional only in the compatibility sections. Explain their locations in the update report. Run the v2 workspace typecheck or a smallest v2 server/client typecheck when dependencies are available; do not leave `node_modules` or other build artifacts in the skill.
