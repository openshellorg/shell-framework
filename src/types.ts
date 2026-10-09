/**
 * Extension manifest as loaded from JSON on disk.
 * Pointers only — no vendored extension source in shell-framework.
 *
 * Canon context: https://github.com/openshellorg/shell-architecture
 */
export type ExtensionRuntime = "dub" | "node" | "cli";

export interface ExtensionDubManifest {
  package: string;
  configuration?: string;
  binary?: string;
}

export interface ExtensionNodeManifest {
  entry: string;
}

export interface ExtensionCliManifest {
  repository?: string;
  binary?: string;
}

export interface ExtensionArchitectureLinks {
  doc?: string;
  topics?: string[];
}

export interface ExtensionManifest {
  schemaVersion: 1;
  $schema?: string;
  id: string;
  name: string;
  repository: string;
  version?: string;
  core?: boolean;
  runtime: ExtensionRuntime;
  dub?: ExtensionDubManifest;
  node?: ExtensionNodeManifest;
  cli?: ExtensionCliManifest;
  architecture?: ExtensionArchitectureLinks;
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

export type ExtensionLoadState = "resolved" | "missing" | "not-applicable";

export interface LoadedExtension {
  registered: RegisteredExtension;
  state: ExtensionLoadState;
  /** Resolved PATH to CLI binary when state is resolved and runtime uses cli. */
  binaryPath?: string;
  /** dub package name when runtime is dub. */
  dubPackage?: string;
  /** Node module namespace when runtime is node and import succeeded. */
  nodeModule?: unknown;
  reason?: string;
}

export class ManifestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ManifestValidationError";
  }
}

const RUNTIMES = new Set<ExtensionRuntime>(["dub", "node", "cli"]);

function readString(
  record: Record<string, unknown>,
  key: string,
  label: string,
  required = false,
): string | undefined {
  const value = record[key];
  if (value === undefined || value === null) {
    if (required) {
      throw new ManifestValidationError(`${label}: "${key}" is required`);
    }
    return undefined;
  }
  if (typeof value !== "string" || value.length === 0) {
    throw new ManifestValidationError(
      `${label}: "${key}" must be a non-empty string`,
    );
  }
  return value;
}

function readObject(
  value: unknown,
  label: string,
): Record<string, unknown> | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new ManifestValidationError(`${label}: expected an object`);
  }
  return value as Record<string, unknown>;
}

export function validateExtensionManifest(
  value: unknown,
  label = "manifest",
): ExtensionManifest {
  const record = readObject(value, label);
  if (!record) {
    throw new ManifestValidationError(`${label}: expected an object`);
  }

  const schemaVersion = record.schemaVersion;
  if (schemaVersion !== 1) {
    throw new ManifestValidationError(
      `${label}: "schemaVersion" must be 1 (got ${String(schemaVersion)})`,
    );
  }

  const id = readString(record, "id", label, true)!;
  const name = readString(record, "name", label, true)!;
  const repository = readString(record, "repository", label, true)!;
  const runtimeRaw = readString(record, "runtime", label, true)!;
  if (!RUNTIMES.has(runtimeRaw as ExtensionRuntime)) {
    throw new ManifestValidationError(
      `${label}: "runtime" must be one of: dub, node, cli`,
    );
  }
  const runtime = runtimeRaw as ExtensionRuntime;

  const manifest: ExtensionManifest = {
    schemaVersion: 1,
    id,
    name,
    repository,
    runtime,
  };

  const schemaUrl = readString(record, "$schema", label);
  if (schemaUrl) manifest.$schema = schemaUrl;

  const version = readString(record, "version", label);
  if (version) manifest.version = version;
  if (record.core === true) manifest.core = true;

  const dubRecord = readObject(record.dub, `${label}.dub`);
  if (dubRecord) {
    const dubPackage = readString(dubRecord, "package", `${label}.dub`, true)!;
    manifest.dub = { package: dubPackage };
    const configuration = readString(dubRecord, "configuration", `${label}.dub`);
    if (configuration) manifest.dub.configuration = configuration;
    const dubBinary = readString(dubRecord, "binary", `${label}.dub`);
    if (dubBinary) manifest.dub.binary = dubBinary;
  }

  const nodeRecord = readObject(record.node, `${label}.node`);
  if (nodeRecord) {
    const entry = readString(nodeRecord, "entry", `${label}.node`, true)!;
    manifest.node = { entry };
  }

  const cliRecord = readObject(record.cli, `${label}.cli`);
  if (cliRecord) {
    manifest.cli = {};
    const cliRepo = readString(cliRecord, "repository", `${label}.cli`);
    if (cliRepo) manifest.cli.repository = cliRepo;
    const cliBinary = readString(cliRecord, "binary", `${label}.cli`);
    if (cliBinary) manifest.cli.binary = cliBinary;
  }

  const archRecord = readObject(record.architecture, `${label}.architecture`);
  if (archRecord) {
    manifest.architecture = {};
    const doc = readString(archRecord, "doc", `${label}.architecture`);
    if (doc) manifest.architecture.doc = doc;
    if (Array.isArray(archRecord.topics)) {
      manifest.architecture.topics = archRecord.topics.map((topic, i) => {
        if (typeof topic !== "string" || topic.length === 0) {
          throw new ManifestValidationError(
            `${label}.architecture.topics[${i}] must be a non-empty string`,
          );
        }
        return topic;
      });
    }
  }

  if (runtime === "dub") {
    if (!manifest.dub) {
      throw new ManifestValidationError(`${label}: dub runtime requires "dub"`);
    }
    if (!manifest.cli?.binary) {
      throw new ManifestValidationError(
        `${label}: dub runtime requires cli.binary for PATH resolution`,
      );
    }
  }
  if (runtime === "cli" && !manifest.cli?.binary) {
    throw new ManifestValidationError(
      `${label}: cli runtime requires cli.binary`,
    );
  }
  if (runtime === "node" && !manifest.node?.entry) {
    throw new ManifestValidationError(
      `${label}: node runtime requires node.entry`,
    );
  }

  return manifest;
}
