/**
 * Extension manifest as loaded from JSON on disk.
 * Pointers only — no vendored extension source in shell-framework.
 */
export interface ExtensionCliManifest {
  repository?: string;
  binary?: string;
}

export interface ExtensionManifest {
  id: string;
  name: string;
  repository: string;
  version?: string;
  package?: string;
  core?: boolean;
  cli?: ExtensionCliManifest;
}

export interface CoreIndex {
  description?: string;
  manifests: string[];
}

export type ExtensionSource = "core" | "manifest";

export interface RegisteredExtension extends ExtensionManifest {
  source: ExtensionSource;
  manifestPath?: string;
  registeredAt: string;
}

export class ManifestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ManifestValidationError";
  }
}

export function validateExtensionManifest(
  value: unknown,
  label = "manifest",
): ExtensionManifest {
  if (value === null || typeof value !== "object") {
    throw new ManifestValidationError(`${label}: expected an object`);
  }
  const record = value as Record<string, unknown>;
  const id = record.id;
  const name = record.name;
  const repository = record.repository;
  if (typeof id !== "string" || id.length === 0) {
    throw new ManifestValidationError(`${label}: "id" must be a non-empty string`);
  }
  if (typeof name !== "string" || name.length === 0) {
    throw new ManifestValidationError(`${label}: "name" must be a non-empty string`);
  }
  if (typeof repository !== "string" || repository.length === 0) {
    throw new ManifestValidationError(
      `${label}: "repository" must be a non-empty string`,
    );
  }
  const manifest: ExtensionManifest = { id, name, repository };
  if (typeof record.version === "string") manifest.version = record.version;
  if (typeof record.package === "string") manifest.package = record.package;
  if (record.core === true) manifest.core = true;
  if (record.cli !== undefined && record.cli !== null && typeof record.cli === "object") {
    const cli = record.cli as Record<string, unknown>;
    manifest.cli = {};
    if (typeof cli.repository === "string") {
      manifest.cli.repository = cli.repository;
    }
    if (typeof cli.binary === "string") {
      manifest.cli.binary = cli.binary;
    }
  }
  return manifest;
}
