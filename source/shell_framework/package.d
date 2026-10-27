/**
 * OpenShellOrg shell-framework: modular extension host.
 *
 * Loads extension manifests from disk, discovers the core set listed in
 * `manifests/core.index.json`, and registers extensions in an in-process
 * registry. The host never downloads or vendors extension source.
 *
 * C and other FFI callers use `shell_framework.capi` (header:
 * `include/shell_framework.h`).
 */
module shell_framework;

public import shell_framework.types;
public import shell_framework.discovery;
public import shell_framework.host;
public import shell_framework.loader;

/// Library version (SemVer). Matches the git tag `v<version>`.
enum string shellFrameworkVersion = "0.1.0";
