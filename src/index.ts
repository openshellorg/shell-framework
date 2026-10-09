import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  discoverCoreExtensions,
  discoverManifestDirectory,
} from "./discovery.js";
import { ExtensionHost, type ExtensionHostOptions } from "./extension-host.js";
import { loadExtensions, type LoadExtensionOptions } from "./loader.js";
import type { LoadedExtension, RegisteredExtension } from "./types.js";

export type {
  CoreIndex,
  ExtensionArchitectureLinks,
  ExtensionCliManifest,
  ExtensionDubManifest,
  ExtensionLoadState,
  ExtensionManifest,
  ExtensionNodeManifest,
  ExtensionRuntime,
  ExtensionSource,
  LoadedExtension,
  RegisteredExtension,
} from "./types.js";
export { ManifestValidationError, validateExtensionManifest } from "./types.js";
export {
  discoverCoreExtensions,
  discoverManifestDirectory,
  loadCoreIndex,
  loadExtensionManifest,
} from "./discovery.js";
export { ExtensionHost } from "./extension-host.js";
export {
  loadExtension,
  loadExtensions,
  resolveBinaryOnPathSync,
  runExtensionCli,
  type LoadExtensionOptions,
  type ResolveBinaryOptions,
  type RunCliOptions,
} from "./loader.js";

export interface BootstrapOptions extends ExtensionHostOptions {
  rootDir?: string;
  /** Also load manifests from manifests/extensions/*.manifest.json */
  includeUserManifests?: boolean;
  /** Resolve PATH / node imports after registration (default true). */
  load?: boolean;
  loadOptions?: LoadExtensionOptions;
}

export interface BootstrappedExtensionHost {
  host: ExtensionHost;
  rootDir: string;
  core: RegisteredExtension[];
  user: RegisteredExtension[];
  loaded: LoadedExtension[];
}

/** Repository root (directory containing manifests/). */
export function defaultPackageRoot(): string {
  const here = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(here, "..");
}

/**
 * Create a host, discover manifests, register them, and resolve load surfaces.
 */
export async function bootstrapExtensionHost(
  options: BootstrapOptions = {},
): Promise<BootstrappedExtensionHost> {
  const rootDir = options.rootDir ?? defaultPackageRoot();
  const host = new ExtensionHost({ now: options.now });
  const core: RegisteredExtension[] = [];
  const user: RegisteredExtension[] = [];

  const discoveredCore = await discoverCoreExtensions({ rootDir });
  for (const { manifest, manifestPath } of discoveredCore) {
    core.push(host.registerFromManifestFile(manifest, manifestPath, "core"));
  }

  if (options.includeUserManifests) {
    const discoveredUser = await discoverManifestDirectory({ rootDir });
    for (const { manifest, manifestPath } of discoveredUser) {
      user.push(host.registerFromManifestFile(manifest, manifestPath, "manifest"));
    }
  }

  const shouldLoad = options.load ?? true;
  const registered = [...core, ...user];
  const loaded = shouldLoad
    ? await loadExtensions(registered, options.loadOptions)
    : registered.map((entry) => ({
        registered: entry,
        state: "not-applicable" as const,
        reason: "load disabled",
      }));

  return { host, rootDir, core, user, loaded };
}

export function createExtensionHost(
  options: ExtensionHostOptions = {},
): ExtensionHost {
  return new ExtensionHost(options);
}
