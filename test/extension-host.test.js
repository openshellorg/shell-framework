import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  bootstrapExtensionHost,
  createExtensionHost,
  discoverCoreExtensions,
} from "../dist/index.js";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

test("discoverCoreExtensions finds Prohelp manifest", async () => {
  const discovered = await discoverCoreExtensions({ rootDir: repoRoot });
  assert.equal(discovered.length, 1);
  assert.equal(discovered[0].manifest.id, "openshellorg/prohelp");
  assert.equal(discovered[0].manifest.runtime, "dub");
  assert.equal(
    discovered[0].manifest.repository,
    "https://github.com/openshellorg/prohelp",
  );
  assert.equal(discovered[0].manifest.dub?.package, "prohelp");
  assert.equal(
    discovered[0].manifest.cli?.repository,
    "https://github.com/openshellorg/prohelp-cli",
  );
});

test("bootstrapExtensionHost registers core extensions", async () => {
  const { host, core, loaded } = await bootstrapExtensionHost({
    rootDir: repoRoot,
    load: false,
  });
  assert.equal(core.length, 1);
  assert.equal(host.size(), 1);
  assert.equal(loaded.length, 1);
  const prohelp = host.get("openshellorg/prohelp");
  assert.ok(prohelp);
  assert.equal(prohelp.source, "core");
  assert.equal(prohelp.core, true);
  assert.match(prohelp.manifestPath ?? "", /prohelp\.manifest\.json$/);
});

test("ExtensionHost rejects duplicate registration", () => {
  const host = createExtensionHost({ now: () => "2026-01-01T00:00:00.000Z" });
  host.register(
    {
      schemaVersion: 1,
      id: "example/demo",
      name: "Demo",
      repository: "https://github.com/example/demo",
      runtime: "cli",
      cli: { binary: "demo" },
    },
    "manifest",
  );
  assert.throws(
    () =>
      host.register(
        {
          schemaVersion: 1,
          id: "example/demo",
          name: "Demo again",
          repository: "https://github.com/example/demo",
          runtime: "cli",
          cli: { binary: "demo" },
        },
        "manifest",
      ),
    /already registered/,
  );
});
