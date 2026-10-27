# Distribution and runtime model

## What ships where

| Artifact | Technology | Published to | Role |
|----------|------------|--------------|------|
| **shell-framework** (this repo) | D + **dub**, C ABI | [dub registry](https://code.dlang.org/packages/shell-framework) / git | Manifest registry, discovery, PATH resolution, CLI spawn, C ABI for other languages |
| **Extensions** (e.g. [prohelp](https://github.com/openshellorg/prohelp)) | D + **dub** | dub registry / git | Shell-agnostic tools and libraries the host points at |
| **Open Shell runtime** | D (`open-shell`) | N/A | Links this library (dub dependency) and reads the same manifest contract |

Nothing here is published to npm. The optional `package` field from the first scaffold was npm-oriented and was removed in favor of `runtime` + `dub` / `node` / `cli`. Core OSO extensions like Prohelp are **D projects**: users install with `dub build` (or OS packages) and put the binary on `PATH`. The host **does not compile D**; it resolves `cli.binary` and can spawn the tool.

## Expected use cases

1. **CI and tooling** - verify core manifests, schema, and that a CI image has `prohelp` on `PATH` when you opt in.
2. **Open Shell** - `open-shell` depends on `shell-framework` through dub and calls the D API directly.
3. **Other hosts** (terminals, IDE and agent hosts, demos in [shell-architecture](https://github.com/openshellorg/shell-architecture)) - load the shared library through the C ABI (`include/shell_framework.h`). C++, Java and JS/TS bindings are planned.

## Runtimes

| `runtime` | Host behavior |
|-----------|----------------|
| `dub` | Requires `dub.package` + `cli.binary`. Resolves the binary on `PATH`; a missing binary reports `missing` with a dub build hint. |
| `cli` | Requires `cli.binary` only (prebuilt or OS install). |
| `node` | Validated, but reported as not applicable: the D host does not embed a JavaScript engine. A Node host can load such modules itself once the planned Node binding exists. |

## Not goals

- Vendoring extension source into `shell-framework`
- Compiling extensions from the host
