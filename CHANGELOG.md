# Changelog

## 0.1.0 - 2026-10-26

### Rewrite in D with a C ABI

- The host is now a D library (dub package `shell-framework`) with the same behavior as the TypeScript host it replaces: manifest schema v1 validation, core index and `manifests/extensions/` discovery, registry, bootstrap, PATH resolution with the dub build hint, and `runExtensionCli`.
- New C ABI (`source/shell_framework/capi.d`, hand-written `include/shell_framework.h`) and a `shared` dub configuration that builds a DLL / shared object for FFI. Bindings for C++, Java and JS/TS are planned.
- `node` runtime manifests still validate, but the D host reports them as not applicable instead of calling `import()`; a Node binding over the C ABI is planned.
- Added `schemas/core-index.schema.json`; tests validate the shipped manifests and core index against the JSON Schemas.
- CI is a dub matrix (Windows and Linux, ldc and dmd) plus a C program linked against the shared library, with the encoding guard kept.
- Why: TypeScript was an unexamined scaffold default. The OpenShellOrg design docs specify D, and other languages reach the host through the C ABI.

### Manifest schema v1 and loading (first landed in the TypeScript host)

- Extension manifest schema v1 (`runtime`: `dub` | `node` | `cli`) with JSON Schema under `schemas/`.
- Extension loading: PATH resolution and `runExtensionCli`.
- Prohelp core manifest aligned to dub + architecture cross-links.
- Documented the distribution model (no npm publish; the host ships on the dub registry).
- Optional `manifests/extensions/` discovery via `includeUserManifests`.
