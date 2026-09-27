# Contributing to shell-framework

This repo is the **extension host** for OpenShellOrg. Architecture and thesis live in [shell-architecture](https://github.com/openshellorg/shell-architecture).

## Layout

- `src/` — host implementation (manifest loading, registration, core discovery)
- `manifests/core/` — JSON manifests that **point at** upstream repos; never vendor extension source here
- `test/` — Node test runner checks against built `dist/`

## Adding a core extension

1. Add `manifests/core/<name>.manifest.json` following the schema in [`docs/extension-manifest.md`](docs/extension-manifest.md).
2. Register the file path in `manifests/core.index.json`.
3. Extend tests if the extension has required fields beyond the base schema.

## Development

```bash
pnpm install
pnpm build
pnpm test
```

Pull requests should keep CI green (`pnpm test` runs typecheck, build, and tests).
