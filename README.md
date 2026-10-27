# shell-framework

**OpenShellOrg modular extension host** - manifests, discovery, registration, and **loading** (PATH resolution + CLI spawn) for shell extensions. The core is written in **D**; every other language reaches it through a small, stable **C ABI**.

## Dual-repo model

OpenShellOrg splits **architecture** from **implementation**:

| Repository | Role |
|------------|------|
| [**shell-architecture**](https://github.com/openshellorg/shell-architecture) | **Canon** - thesis, Tool Runs, command channels, Antora docs, diagrams |
| **shell-framework** (this repo) | **Extension host** - manifest schema, core registry, discovery, load + spawn APIs |

Do not duplicate architecture docs here. See [docs/architecture-crosslinks.md](docs/architecture-crosslinks.md) for paired Antora pages.

## Distribution

| Component | Stack | Published to |
|-----------|-------|--------------|
| **This host** | D + dub, C ABI | [code.dlang.org/packages/shell-framework](https://code.dlang.org/packages/shell-framework) |
| **Extensions (Prohelp, ...)** | D + dub | dub / git - see [docs/distribution-and-runtime.md](docs/distribution-and-runtime.md) |

The host resolves **`cli.binary` on PATH** (after you `dub build` the extension upstream) and can spawn it. It does not compile D. Nothing is published to npm.

## What lives here

- **`source/shell_framework/`** - D extension host: manifest validation, discovery, registry, `loadExtension` / `runExtensionCli`
- **`source/shell_framework/capi.d`** + **`include/shell_framework.h`** - C ABI for FFI callers
- **`manifests/core/`** - pointers to first-party core extensions (repos/packages), not vendored source
- **`schemas/`** - JSON Schemas for manifests (v1) and the core index; tests validate the shipped manifests against them
- **`manifests/extensions/`** - optional user manifests
- **Tests + CI** - dub unittests and a C program linked against the shared library, on Windows and Linux with ldc and dmd

## Core extensions

Core extensions are registered **by manifest only**. The host does not embed their code.

| Extension | Manifest | Upstream |
|-----------|----------|----------|
| Prohelp | [`manifests/core/prohelp.manifest.json`](manifests/core/prohelp.manifest.json) | [openshellorg/prohelp](https://github.com/openshellorg/prohelp) / CLI: [prohelp-cli](https://github.com/openshellorg/prohelp-cli) |

## Quick start (D)

```bash
dub test                    # unittests
dub build --config=library  # static library (default)
dub build --config=shared   # shell-framework.dll / libshell-framework.so for FFI
```

Add it to a D project with `dub add shell-framework`, then:

```d
import shell_framework;
import std.stdio : writeln;

auto b = bootstrapExtensionHost("path/to/shell-framework"); // core index + PATH resolution
foreach (l; b.loaded)
    writeln(l.registered.id, ": ", l.reason); // openshellorg/prohelp: resolved prohelp

if (b.loaded[0].state == LoadState.resolved)
{
    RunCliOptions o;
    o.args = ["?"];
    o.timeoutMs = 5000;
    writeln(runExtensionCli(b.loaded[0], o).stdout);
}
```

## C ABI (other languages)

`include/shell_framework.h` is hand-written and matches `capi.d`. All functions are `extern "C"` and never throw.

| Function | Purpose |
|----------|---------|
| `sf_host_create` / `sf_host_destroy` | Opaque `sf_host*`; create also initializes the D runtime (reference counted) |
| `sf_load_manifest_file(host, path)` | Register one manifest file |
| `sf_load_manifest_json(host, json, len)` | Register manifest JSON from memory |
| `sf_discover(host, dir)` | Register the core set (`dir/manifests/core.index.json`) plus `manifests/extensions/`, or every `*.manifest.json` in `dir`; returns the count |
| `sf_extension_count` / `sf_extension_get(host, i, &info)` | Enumerate (sorted by id) into `sf_extension_info` |
| `sf_extension_load(host, i, &load)` | Resolve the CLI on PATH (`SF_LOAD_RESOLVED` / `MISSING` / `NOT_APPLICABLE`, path, reason); never spawns |
| `sf_extension_to_json(host, i)` | Manifest JSON, caller-owned, release with `sf_free` |
| `sf_last_error(host)` | Message for the last failed call (`NULL` host: host-less errors) |
| `sf_free(ptr)` | Free memory the library handed to the caller |

**Ownership:** strings in `sf_extension_info` and from `sf_last_error` belong to the host (do not free; info strings live until `sf_host_destroy`). `sf_load_info` strings live until the next `sf_extension_load`. Only `sf_extension_to_json` results are yours, and they go back through `sf_free`. A host is not thread-safe. See the header for the full rules and `test/c/test_capi.c` for a working example.

## Bindings roadmap (planned, not done)

- **C++** - header-only RAII wrapper (`sf::Host` owning `sf_host*`, `std::string_view` accessors)
- **Java** - Panama (Foreign Function & Memory API) binding over the shared library
- **JS / TS** - Node-API addon, or a `koffi` FFI binding for a no-compile option

Spawning CLIs is D-only for now (`runExtensionCli`); C callers spawn the resolved `binary_path` themselves. Until the bindings land, call the C ABI directly.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for layout and manifest conventions, and [`docs/extension-manifest.md`](docs/extension-manifest.md) for the manifest format.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

## Related projects

- [shell-architecture](https://github.com/openshellorg/shell-architecture) - canon docs
- [prohelp](https://github.com/openshellorg/prohelp) - progressive CLI help (first core extension)
- [docs](https://github.com/openshellorg/docs) - SOS certification and org docs site

## License

MIT - see [LICENSE](LICENSE).
