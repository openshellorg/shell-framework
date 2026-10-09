# Distribution and runtime model

## Two different “packages”

| Artifact | Technology | Published to npm? | Role |
|----------|------------|-------------------|------|
| **shell-framework** (this repo) | TypeScript / Node | **No** (`private: true`) | Manifest registry, discovery, PATH resolution, optional `import()` for Node extensions, CI |
| **Extensions** (e.g. [prohelp](https://github.com/openshellorg/prohelp)) | D + **dub** | **No** (dub registry / git) | Shell-agnostic tools and libraries the host points at |
| **Future Open Shell runtime** | D (`open-shell`) | N/A | Will embed or call the same manifest contract; not replaced by this Node host |

The optional `package` field from the first scaffold was **npm-oriented** and was removed in favor of `runtime` + `dub` / `node` / `cli`. Core OSO extensions like Prohelp are **D projects**: users install with `dub build` (or OS packages) and put the binary on `PATH`. This host **does not compile D**; it resolves `cli.binary` and can spawn the tool.

## Expected use cases

1. **CI and tooling** — verify core manifests, schema, and that a CI image has `prohelp` on `PATH` when you opt in.
2. **Agent / IDE hosts** — Node-based hosts (terminals, demos in [shell-architecture](https://github.com/openshellorg/shell-architecture)) load manifests and delegate to CLIs.
3. **Future D shell** — `open-shell` reads the same manifest shape (or a generated copy) and links dub libraries directly; this repo stays the **reference host** for manifests and discovery.

## Runtimes

| `runtime` | Host behavior |
|-----------|----------------|
| `dub` | Requires `dub.package` + `cli.binary`. Resolves binary on `PATH`; missing binary → `missing` with dub build hint. |
| `cli` | Requires `cli.binary` only (prebuilt or OS install). |
| `node` | `import(node.entry)` for JavaScript/TypeScript extension modules installed beside the host. |

## Not goals

- Vendoring extension source into `shell-framework`
- Publishing `@openshellorg/shell-framework` to npm (install via git submodule / monorepo path / future dub wrapper if needed)
