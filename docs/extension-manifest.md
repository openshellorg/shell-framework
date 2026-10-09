# Extension manifest

Core and third-party extensions are described by JSON manifests ([`schemas/extension-manifest.schema.json`](../schemas/extension-manifest.schema.json)). The host loads manifests from disk, registers them, and **resolves** an install surface (PATH binary or Node `import()`). It does not clone or embed extension repositories.

See also: [distribution and runtime](distribution-and-runtime.md), [architecture cross-links](architecture-crosslinks.md).

## Required fields

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | `1` | Manifest revision |
| `id` | string | Stable identifier (e.g. `openshellorg/prohelp`) |
| `name` | string | Display name |
| `repository` | string | Canonical upstream repo URL |
| `runtime` | `"dub"` \| `"node"` \| `"cli"` | How the host loads the extension |

## Optional fields

| Field | Type | Description |
|-------|------|-------------|
| `$schema` | string | Schema URL for editors |
| `version` | string | Version hint (not used for dub/npm resolution) |
| `core` | boolean | When `true`, listed in `manifests/core.index.json` |
| `dub` | object | `package`, optional `configuration`, optional `binary` |
| `node` | object | `entry` — passed to dynamic `import()` |
| `cli` | object | `binary` (required for `dub`/`cli`), optional `repository` |
| `architecture` | object | `doc` URL, `topics[]` stems in shell-architecture |

## Runtime rules

- **`dub`** — OSO D extensions (e.g. Prohelp). Requires `dub.package` and `cli.binary`. Host checks `PATH`; user builds with dub upstream.
- **`cli`** — Preinstalled binary only.
- **`node`** — Optional JS/TS modules; `node.entry` must be importable from the host process.

## Example (Prohelp)

See [`manifests/core/prohelp.manifest.json`](../manifests/core/prohelp.manifest.json).

## User extensions

Drop additional `*.manifest.json` files under `manifests/extensions/` and pass `includeUserManifests: true` to `bootstrapExtensionHost()`.
