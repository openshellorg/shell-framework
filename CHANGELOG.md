# Changelog

## 0.1.0

- Extension manifest schema v1 (`runtime`: `dub` | `node` | `cli`) with JSON Schema under `schemas/`.
- Real extension loading: PATH resolution, optional Node `import()`, `runExtensionCli`.
- Prohelp core manifest aligned to dub + architecture cross-links.
- Document distribution model (no npm publish for host or D extensions).
- Optional `manifests/extensions/` discovery via `includeUserManifests`.
