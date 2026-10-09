import { readdir } from "node:fs/promises";
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

export interface DiscoverManifestDirectoryOptions {
  rootDir?: string;
  /** Directory relative to rootDir (default manifests/extensions). */
  directory?: string;
}

/**
 * Load every `*.manifest.json` in a directory (non-core user extensions).
 */
export async function discoverManifestDirectory(
  options: DiscoverManifestDirectoryOptions = {},
): Promise<Array<{ manifest: ExtensionManifest; manifestPath: string }>> {
  const rootDir = options.rootDir ?? process.cwd();
  const directory =
    options.directory ?? path.join("manifests", "extensions");
  const dirAbs = path.resolve(rootDir, directory);
  let names: string[];
  try {
    names = await readdir(dirAbs);
  } catch {
    return [];
  }
  const results: Array<{ manifest: ExtensionManifest; manifestPath: string }> =
    [];
  for (const name of names.sort()) {
    if (!name.endsWith(".manifest.json")) continue;
    const manifestPath = path.join(dirAbs, name);
    const manifest = await loadExtensionManifest(manifestPath);
    results.push({ manifest, manifestPath });
  }
  return results;
}
