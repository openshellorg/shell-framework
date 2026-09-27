# shell-framework

**OpenShellOrg modular extension host** — manifests, discovery, and registration for shell extensions. This repository implements the host stub that loads extension manifests and registers core and user-supplied extensions.

## Dual-repo model

OpenShellOrg splits **architecture** from **implementation**:

| Repository | Role |
|------------|------|
| [**shell-architecture**](https://github.com/openshellorg/shell-architecture) | **Canon** — thesis, Tool Runs, command channels, Antora docs, diagrams |
| **shell-framework** (this repo) | **Extension host** — manifest schema, core extension registry, discovery, host APIs |

Do not duplicate architecture docs here. When you need design rationale (structured pipelines, SOS relationship, host identity, env refresh plans), use [shell-architecture](https://github.com/openshellorg/shell-architecture).

## What lives here

- **`manifests/core/`** — pointers to first-party core extensions (repos/packages), not vendored source
- **`src/`** — TypeScript extension host: load manifests, register extensions, discover bundled core set
- **Tests + CI** — build and verify core registration (e.g. Prohelp) without cloning extension repos

## Core extensions

Core extensions are registered **by manifest only**. The host does not embed their code.

| Extension | Manifest | Upstream |
|-----------|----------|----------|
| Prohelp | [`manifests/core/prohelp.manifest.json`](manifests/core/prohelp.manifest.json) | [openshellorg/prohelp](https://github.com/openshellorg/prohelp) · CLI: [prohelp-cli](https://github.com/openshellorg/prohelp-cli) |

## Quick start

```bash
pnpm install
pnpm build
pnpm test
```

Programmatic bootstrap:

```ts
import { bootstrapExtensionHost } from "@openshellorg/shell-framework";

const host = await bootstrapExtensionHost();
console.log(host.listCore()); // includes openshellorg/prohelp
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for layout and manifest conventions.

## Related projects

- [shell-architecture](https://github.com/openshellorg/shell-architecture) — canon docs
- [prohelp](https://github.com/openshellorg/prohelp) — structured help / gutter tooling (first core extension)
- [docs](https://github.com/openshellorg/docs) — SOS certification and org docs site

## License

MIT — see [LICENSE](LICENSE).
