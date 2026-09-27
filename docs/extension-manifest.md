# Extension manifest

Core and third-party extensions are described by JSON manifests. The host loads manifests from disk and registers them; it does not download or embed extension repositories.

## Required fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Stable identifier (e.g. `openshellorg/prohelp`) |
| `name` | string | Display name |
| `repository` | string | Canonical source repo URL |
| `core` | boolean | When `true`, discovered via `manifests/core/` |

## Optional fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Manifest or pinned extension version hint |
| `package` | string | npm package name when published |
| `cli` | object | CLI-related pointers |
| `cli.repository` | string | CLI repo URL (e.g. prohelp-cli) |
| `cli.binary` | string | Expected CLI command name |

## Example (Prohelp)

See [`manifests/core/prohelp.manifest.json`](../manifests/core/prohelp.manifest.json).
