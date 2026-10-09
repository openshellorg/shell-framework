import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  bootstrapExtensionHost,
  loadExtension,
  resolveBinaryOnPathSync,
  runExtensionCli,
  validateExtensionManifest,
} from "../dist/index.js";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

test("resolveBinaryOnPathSync finds node on PATH", () => {
  const resolved = resolveBinaryOnPathSync("node");
  assert.ok(resolved, "expected node binary on PATH in CI");
});

test("loadExtension resolves node runtime via import", async () => {
  const manifest = validateExtensionManifest({
    schemaVersion: 1,
    id: "test/node-os",
    name: "Node OS builtin",
    repository: "https://example.com/node",
    runtime: "node",
    node: { entry: "node:os" },
  });
  const loaded = await loadExtension(
    {
      ...manifest,
      source: "manifest",
      registeredAt: "2026-01-01T00:00:00.000Z",
    },
    { resolve: true },
  );
  assert.equal(loaded.state, "resolved");
  assert.ok(loaded.nodeModule);
});

test("loadExtension reports missing dub CLI with dub hint", async () => {
  const manifest = validateExtensionManifest({
    schemaVersion: 1,
    id: "test/missing-cli",
    name: "Missing",
    repository: "https://example.com/missing",
    runtime: "dub",
    dub: { package: "prohelp", configuration: "executable" },
    cli: { binary: "definitely-not-installed-prohelp-oso" },
  });
  const loaded = await loadExtension(
    {
      ...manifest,
      source: "manifest",
      registeredAt: "2026-01-01T00:00:00.000Z",
    },
    { resolve: true, pathEnv: "/usr/bin" },
  );
  assert.equal(loaded.state, "missing");
  assert.match(loaded.reason ?? "", /prohelp/);
});

test("bootstrapExtensionHost loads core manifests and resolves prohelp when on PATH", async () => {
  const lookup = (binary) =>
    binary === "prohelp" ? "/tmp/fake-prohelp" : undefined;
  const { loaded, core } = await bootstrapExtensionHost({
    rootDir: repoRoot,
    loadOptions: {
      lookup: (binary) => lookup(binary),
    },
  });
  assert.equal(core.length, 1);
  assert.equal(loaded.length, 1);
  const prohelp = loaded[0];
  assert.equal(prohelp.registered.id, "openshellorg/prohelp");
  assert.equal(prohelp.state, "resolved");
  assert.equal(prohelp.binaryPath, "/tmp/fake-prohelp");
});

test("runExtensionCli spawns resolved binary", async () => {
  const loaded = {
    registered: {
      schemaVersion: 1,
      id: "test/node",
      name: "Node",
      repository: "https://example.com",
      runtime: "cli",
      cli: { binary: "node" },
      source: "manifest",
      registeredAt: "2026-01-01T00:00:00.000Z",
    },
    state: "resolved",
    binaryPath: resolveBinaryOnPathSync("node"),
  };
  const { code, stdout } = await runExtensionCli(loaded, {
    args: ["-e", "console.log('oso-host')"],
    timeoutMs: 10_000,
  });
  assert.equal(code, 0);
  assert.match(stdout, /oso-host/);
});
