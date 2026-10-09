# shell-framework

**OpenShellOrg modular extension host** — manifests, discovery, registration, and **loading** (PATH / Node) for shell extensions. This repository implements the reference host in TypeScript for CI and Node-based tooling; the **Open Shell runtime** is D ([open-shell](https://github.com/openshellorg/shell-architecture/blob/main/docs/modules/ROOT/pages/open-shell.adoc)) and will consume the same manifest contract.

## Dual-repo model

OpenShellOrg splits **architecture** from **implementation**:

| Repository | Role |
|------------|------|
| [**shell-architecture**](https://github.com/openshellorg/shell-architecture) | **Canon** — thesis, Tool Runs, command channels, Antora docs, diagrams |
| **shell-framework** (this repo) | **Extension host** — manifest schema, core registry, discovery, load + spawn APIs |

Do not duplicate architecture docs here. See [docs/architecture-crosslinks.md](docs/architecture-crosslinks.md) for paired Antora pages.

## npm vs dub (what gets published where)

| Component | Stack | npm publish? |
|-----------|-------|----------------|
| **This host** | Node / pnpm | **No** — `private: true`; install from git or monorepo path |
| **Extensions (Prohelp, …)** | D + **dub** | **dub / git**, not npm — see [docs/distribution-and-runtime.md](docs/distribution-and-runtime.md) |

The host resolves **`cli.binary` on PATH** (after you `dub build` upstream) or **`import()`** for optional Node extensions. It does not compile D.

## What lives here

- **`schemas/`** — JSON Schema for manifests
- **`manifests/core/`** — pointers to first-party core extensions (no vendored source)
- **`src/`** — discovery, registry, `loadExtension` / `runExtensionCli`
- **Tests + CI** — schema validation and loader behavior (Prohelp optional on PATH)

## Core extensions

| Extension | Manifest | Upstream |
|-----------|----------|----------|
| Prohelp | [`manifests/core/prohelp.manifest.json`](manifests/core/prohelp.manifest.json) | [prohelp](https://github.com/openshellorg/prohelp) · [prohelp-cli](https://github.com/openshellorg/prohelp-cli) |

## Quick start

```bash
pnpm install
pnpm build
pnpm test
```

Programmatic bootstrap:

```ts
import { bootstrapExtensionHost, runExtensionCli } from "@openshellorg/shell-framework";

const { host, loaded } = await bootstrapExtensionHost();
console.log(host.listCore());

const prohelp = loaded.find((e) => e.registered.id === "openshellorg/prohelp");
if (prohelp?.state === "resolved") {
  await runExtensionCli(prohelp, { args: ["?"], timeoutMs: 5000 });
}
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/extension-manifest.md`](docs/extension-manifest.md).

## Related projects

- [shell-architecture](https://github.com/openshellorg/shell-architecture) — canon docs
- [prohelp](https://github.com/openshellorg/prohelp) — progressive CLI help (first core extension)
- [docs](https://github.com/openshellorg/docs) — SOS certification and org docs site

## License

MIT — see [LICENSE](LICENSE).
