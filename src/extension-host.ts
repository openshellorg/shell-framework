import type {
  ExtensionManifest,
  ExtensionSource,
  RegisteredExtension,
} from "./types.js";
import { validateExtensionManifest } from "./types.js";

export interface ExtensionHostOptions {
  /** ISO timestamp for registrations (tests). */
  now?: () => string;
}

/**
 * In-process registry for extension manifests loaded by the host.
 */
export class ExtensionHost {
  readonly #extensions = new Map<string, RegisteredExtension>();
  readonly #now: () => string;

  constructor(options: ExtensionHostOptions = {}) {
    this.#now = options.now ?? (() => new Date().toISOString());
  }

  register(
    manifestInput: ExtensionManifest,
    source: ExtensionSource,
    manifestPath?: string,
  ): RegisteredExtension {
    const manifest = validateExtensionManifest(manifestInput);
    if (this.#extensions.has(manifest.id)) {
      throw new Error(`Extension already registered: ${manifest.id}`);
    }
    const registered: RegisteredExtension = {
      ...manifest,
      source,
      manifestPath,
      registeredAt: this.#now(),
    };
    this.#extensions.set(manifest.id, registered);
    return registered;
  }

  registerFromManifestFile(
    manifest: ExtensionManifest,
    manifestPath: string,
    source: ExtensionSource = "manifest",
  ): RegisteredExtension {
    return this.register(manifest, source, manifestPath);
  }

  get(id: string): RegisteredExtension | undefined {
    return this.#extensions.get(id);
  }

  has(id: string): boolean {
    return this.#extensions.has(id);
  }

  list(): RegisteredExtension[] {
    return [...this.#extensions.values()].sort((a, b) =>
      a.id.localeCompare(b.id),
    );
  }

  listCore(): RegisteredExtension[] {
    return this.list().filter((entry) => entry.core === true);
  }

  size(): number {
    return this.#extensions.size;
  }
}
