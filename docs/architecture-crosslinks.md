# Architecture cross-links

Canon design lives in [**shell-architecture**](https://github.com/openshellorg/shell-architecture). This repo implements the **extension host** only; link here instead of copying thesis text.

## Dual-repo

| Repo | Link |
|------|------|
| Canon (thesis, Tool Runs, channels) | [openshellorg/shell-architecture](https://github.com/openshellorg/shell-architecture) |
| Extension host (this repo) | [openshellorg/shell-framework](https://github.com/openshellorg/shell-framework) |

## Pages that pair with manifests

Manifests may include `architecture.doc` and `architecture.topics`. Prohelp uses:

| Topic | Architecture page |
|-------|-------------------|
| Prohelp gutter / overlay help | [prohelp-gutter.adoc](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/prohelp-gutter.adoc) |
| Open Shell runtime (D) | [open-shell.adoc](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/open-shell.adoc) |
| Command channels (stdout/stderr/diag) | [command-channels.adoc](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/command-channels.adoc) |
| Tool runs & diagnostics | [tool-run-diagnostics.adoc](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/tool-run-diagnostics.adoc) |
| Host chrome negotiation | [host-chrome-negotiation.adoc](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/host-chrome-negotiation.adoc) |
| Display layers | [shell-display-layers.adoc](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/shell-display-layers.adoc) |

## First core extension

| Extension | Code | CLI bridge | Manifest |
|-----------|------|------------|----------|
| Prohelp | [prohelp](https://github.com/openshellorg/prohelp) | [prohelp-cli](https://github.com/openshellorg/prohelp-cli) | [`prohelp.manifest.json`](../manifests/core/prohelp.manifest.json) |

Prohelp is **optional** in the shell runtime (see open-shell + prohelp-gutter); the host still registers it as a **core manifest pointer** so tooling knows the default extension set.
