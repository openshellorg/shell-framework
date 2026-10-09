import { spawn } from "node:child_process";
import { accessSync, constants as fsConstants } from "node:fs";
import path from "node:path";

import type {
  ExtensionManifest,
  LoadedExtension,
  RegisteredExtension,
} from "./types.js";

export interface ResolveBinaryOptions {
  pathEnv?: string;
  /** Test hook: map binary name to absolute path (skip real PATH walk). */
  lookup?: (binary: string, pathEnv: string) => string | undefined;
}

const defaultPathEnv = (): string =>
  process.env.PATH ?? process.env.Path ?? "";

/**
 * Resolve a command name on PATH (platform PATH separator).
 */
export function resolveBinaryOnPathSync(
  binary: string,
  options: ResolveBinaryOptions = {},
): string | undefined {
  const pathEnv = options.pathEnv ?? defaultPathEnv();
  if (options.lookup) {
    return options.lookup(binary, pathEnv);
  }
  const sep = process.platform === "win32" ? ";" : ":";
  const dirs = pathEnv.split(sep).filter(Boolean);
  const extensions =
    process.platform === "win32"
      ? (process.env.PATHEXT ?? ".EXE;.CMD;.BAT;.COM")
          .split(";")
          .map((ext) => ext.toLowerCase())
      : [""];
  for (const dir of dirs) {
    for (const ext of extensions) {
      const candidate = path.join(dir, binary + ext);
      try {
        accessSync(candidate, fsConstants.X_OK);
        return candidate;
      } catch {
        // continue
      }
    }
  }
  return undefined;
}

export interface LoadExtensionOptions extends ResolveBinaryOptions {
  /** When false, only validate manifest shape and skip PATH / import (default true). */
  resolve?: boolean;
}

function cliBinaryName(manifest: ExtensionManifest): string | undefined {
  return manifest.cli?.binary ?? manifest.dub?.binary;
}

/**
 * Resolve install surface for one registered extension (does not spawn).
 */
export async function loadExtension(
  registered: RegisteredExtension,
  options: LoadExtensionOptions = {},
): Promise<LoadedExtension> {
  const resolve = options.resolve ?? true;
  const manifest = registered;

  if (!resolve) {
    return {
      registered,
      state: "not-applicable",
      reason: "resolve disabled",
    };
  }

  if (manifest.runtime === "node") {
    const entry = manifest.node!.entry;
    try {
      const nodeModule = await import(entry);
      return {
        registered,
        state: "resolved",
        nodeModule,
        reason: `imported ${entry}`,
      };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : String(error);
      return {
        registered,
        state: "missing",
        reason: `node import failed: ${message}`,
      };
    }
  }

  const binary = cliBinaryName(manifest);
  if (!binary) {
    return {
      registered,
      state: "missing",
      reason: "no cli.binary configured",
    };
  }

  const binaryPath = resolveBinaryOnPathSync(binary, options);
  if (!binaryPath) {
    const dubHint =
      manifest.runtime === "dub" && manifest.dub
        ? ` (build with dub: package "${manifest.dub.package}"${
            manifest.dub.configuration
              ? `, configuration "${manifest.dub.configuration}"`
              : ""
          })`
        : "";
    return {
      registered,
      state: "missing",
      dubPackage: manifest.dub?.package,
      reason: `binary "${binary}" not found on PATH${dubHint}`,
    };
  }

  return {
    registered,
    state: "resolved",
    binaryPath,
    dubPackage: manifest.dub?.package,
    reason: `resolved ${binary}`,
  };
}

export async function loadExtensions(
  registered: RegisteredExtension[],
  options: LoadExtensionOptions = {},
): Promise<LoadedExtension[]> {
  const loaded: LoadedExtension[] = [];
  for (const entry of registered) {
    loaded.push(await loadExtension(entry, options));
  }
  return loaded;
}

export interface RunCliOptions {
  args?: string[];
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
}

/**
 * Spawn the extension CLI (must be resolved on PATH). Returns exit code and streams.
 */
export function runExtensionCli(
  loaded: LoadedExtension,
  options: RunCliOptions = {},
): Promise<{ code: number | null; stdout: string; stderr: string }> {
  if (loaded.state !== "resolved" || !loaded.binaryPath) {
    return Promise.reject(
      new Error(
        loaded.reason ??
          `Extension ${loaded.registered.id} is not resolved for CLI spawn`,
      ),
    );
  }

  const args = options.args ?? [];
  return new Promise((resolve, reject) => {
    const child = spawn(loaded.binaryPath!, args, {
      cwd: options.cwd,
      env: { ...process.env, ...options.env },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    child.stderr?.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    let timeout: NodeJS.Timeout | undefined;
    if (options.timeoutMs !== undefined && options.timeoutMs > 0) {
      timeout = setTimeout(() => {
        child.kill("SIGTERM");
        reject(new Error(`CLI timed out after ${options.timeoutMs}ms`));
      }, options.timeoutMs);
    }

    child.on("error", reject);
    child.on("close", (code) => {
      if (timeout) clearTimeout(timeout);
      resolve({ code, stdout, stderr });
    });
  });
}
