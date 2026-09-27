import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  type CoreIndex,
  type ExtensionManifest,
  ManifestValidationError,
  validateExtensionManifest,
} from "./types.js";

export async function loadJsonFile(filePath: string): Promise<unknown> {
  const raw = await readFile(filePath, "utf8");
  try {
    return JSON.parse(raw) as unknown;
  } catch {
    throw new ManifestValidationError(`Invalid JSON: ${filePath}`);
  }
}

export async function loadExtensionManifest(
  manifestPath: string,
): Promise<ExtensionManifest> {
  const parsed = await loadJsonFile(manifestPath);
  return validateExtensionManifest(parsed, manifestPath);
}

export async function loadCoreIndex(indexPath: string): Promise<CoreIndex> {
  const parsed = await loadJsonFile(indexPath);
  if (parsed === null || typeof parsed !== "object") {
    throw new ManifestValidationError(`${indexPath}: expected an object`);
  }
  const record = parsed as Record<string, unknown>;
  if (!Array.isArray(record.manifests)) {
    throw new ManifestValidationError(`${indexPath}: "manifests" must be an array`);
  }
  const manifests = record.manifests.map((entry, i) => {
    if (typeof entry !== "string" || entry.length === 0) {
      throw new ManifestValidationError(
        `${indexPath}: manifests[${i}] must be a non-empty string path`,
      );
    }
    return entry;
  });
  const description =
    typeof record.description === "string" ? record.description : undefined;
  return { description, manifests };
}

export interface DiscoverCoreOptions {
  /** Repository root (defaults to cwd). */
  rootDir?: string;
  /** Path to core index JSON relative to rootDir. */
  coreIndexPath?: string;
}

/**
 * Resolve and load all core extension manifests listed in manifests/core.index.json.
 */
export async function discoverCoreExtensions(
  options: DiscoverCoreOptions = {},
): Promise<Array<{ manifest: ExtensionManifest; manifestPath: string }>> {
  const rootDir = options.rootDir ?? process.cwd();
  const coreIndexPath =
    options.coreIndexPath ?? path.join("manifests", "core.index.json");
  const indexAbs = path.resolve(rootDir, coreIndexPath);
  const index = await loadCoreIndex(indexAbs);

  const results: Array<{ manifest: ExtensionManifest; manifestPath: string }> =
    [];
  for (const relativePath of index.manifests) {
    const manifestPath = path.resolve(rootDir, relativePath);
    const manifest = await loadExtensionManifest(manifestPath);
    if (manifest.core !== true) {
      throw new ManifestValidationError(
        `${manifestPath}: core index entries must set "core": true`,
      );
    }
    results.push({ manifest, manifestPath });
  }
  return results;
}
