import path from "node:path";
import { fileURLToPath } from "node:url";

import { discoverCoreExtensions } from "./discovery.js";
import { ExtensionHost, type ExtensionHostOptions } from "./extension-host.js";
import type { RegisteredExtension } from "./types.js";

export type {
  CoreIndex,
  ExtensionCliManifest,
  ExtensionManifest,
  ExtensionSource,
  RegisteredExtension,
} from "./types.js";
export { ManifestValidationError, validateExtensionManifest } from "./types.js";
export { discoverCoreExtensions, loadCoreIndex, loadExtensionManifest } from "./discovery.js";
export { ExtensionHost } from "./extension-host.js";

export interface BootstrapOptions extends ExtensionHostOptions {
  rootDir?: string;
}

export interface BootstrappedExtensionHost {
  host: ExtensionHost;
  rootDir: string;
  core: RegisteredExtension[];
}

/** Repository root (directory containing manifests/). */
export function defaultPackageRoot(): string {
  const here = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(here, "..");
}

/**
 * Create a host, discover core manifests under rootDir, and register them.
 */
export async function bootstrapExtensionHost(
  options: BootstrapOptions = {},
): Promise<BootstrappedExtensionHost> {
  const rootDir = options.rootDir ?? defaultPackageRoot();
  const host = new ExtensionHost({ now: options.now });
  const discovered = await discoverCoreExtensions({ rootDir });
  const core: RegisteredExtension[] = [];
  for (const { manifest, manifestPath } of discovered) {
    core.push(host.registerFromManifestFile(manifest, manifestPath, "core"));
  }
  return { host, rootDir, core };
}

export function createExtensionHost(
  options: ExtensionHostOptions = {},
): ExtensionHost {
  return new ExtensionHost(options);
}
