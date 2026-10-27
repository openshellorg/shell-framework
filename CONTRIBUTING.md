# Contributing to shell-framework

This repo is the **extension host** for OpenShellOrg. Architecture and thesis live in [shell-architecture](https://github.com/openshellorg/shell-architecture).

## Layout

- `source/shell_framework/` - D host implementation (manifest validation, discovery, registration, PATH loading, CLI spawn)
- `source/shell_framework/capi.d` + `include/shell_framework.h` - C ABI; change both together
- `manifests/core/` - JSON manifests that **point at** upstream repos; never vendor extension source here
- `schemas/` - JSON Schemas for manifests and the core index
- `docs/` - manifest reference, distribution model, architecture cross-links
- `test/c/` - C program that links the shared library through the header

## Adding a core extension

1. Add `manifests/core/<name>.manifest.json` following [`schemas/extension-manifest.schema.json`](schemas/extension-manifest.schema.json) and [`docs/extension-manifest.md`](docs/extension-manifest.md).
2. Register the file path in `manifests/core.index.json`.
3. Extend tests if the extension has required fields beyond the base schema.

## Development

```bash
dub test
dub build --config=shared
```

Pull requests should keep CI green (dub unittests plus the C ABI test on Windows and Linux, ldc and dmd).
