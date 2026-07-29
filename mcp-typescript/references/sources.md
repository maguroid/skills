# Source Pins

The bundled files are selected from official stable releases.

| Bundled path | Upstream | Release tag | Commit | Upstream paths retained |
| --- | --- | --- | --- | --- |
| `specification/` | `modelcontextprotocol/modelcontextprotocol` | `2026-07-28` | `5f5440bb` | `docs/specification/2026-07-28/` text, `schema/2026-07-28/schema.{ts,json}`, `LICENSE` |
| `typescript-sdk/` | `modelcontextprotocol/typescript-sdk` | `@modelcontextprotocol/server@2.0.0` | `cc4b4161` | Consumer-facing Markdown under `docs/`, `LICENSE` |

The SDK tag identifies the shared workspace commit for the aligned v2 split packages. The bundled SDK documentation is the default for new work, not evidence of a target project's installed version. For existing projects, inspect their installed packages and obtain the matching official stable tag when version-specific source or documentation is needed.
