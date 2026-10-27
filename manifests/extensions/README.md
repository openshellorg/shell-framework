# User extension manifests

Place optional `*.manifest.json` files here. They are loaded when `bootstrapExtensionHost` runs with `BootstrapOptions.includeUserManifests = true` (D), and always by `sf_discover` (C ABI).

Core extensions stay in [`manifests/core/`](../core/) and are listed in [`core.index.json`](../core.index.json).
