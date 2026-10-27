/// Manifest loading and discovery (core index + directory scan).
module shell_framework.discovery;

import std.algorithm : sort;
import std.array : array;
import std.file : dirEntries, exists, isDir, readText, SpanMode;
import std.json;
import std.path : absolutePath, buildNormalizedPath, buildPath;
import std.conv : to;
import std.array : replace;

import shell_framework.types;

/// A manifest together with the absolute path it was loaded from.
struct DiscoveredManifest
{
    ExtensionManifest manifest;
    string manifestPath;
}

/// Read and parse a JSON file; malformed JSON raises `ManifestValidationError`.
JSONValue loadJsonFile(string filePath)
{
    const raw = readText(filePath);
    try
        return parseJSON(raw);
    catch (JSONException)
        throw new ManifestValidationError("Invalid JSON: " ~ filePath);
}

/// Parse a manifest from a JSON string.
ExtensionManifest parseExtensionManifest(string json, string label = "manifest")
{
    JSONValue v;
    try
        v = parseJSON(json);
    catch (JSONException)
        throw new ManifestValidationError("Invalid JSON: " ~ label);
    return validateExtensionManifest(v, label);
}

/// Load and validate a manifest file.
ExtensionManifest loadExtensionManifest(string manifestPath)
{
    return validateExtensionManifest(loadJsonFile(manifestPath), manifestPath);
}

/// Load `core.index.json`.
CoreIndex loadCoreIndex(string indexPath)
{
    auto parsed = loadJsonFile(indexPath);
    if (parsed.type != JSONType.object)
        throw new ManifestValidationError(indexPath ~ ": expected an object");
    auto rec = parsed.object;
    auto mp = "manifests" in rec;
    if (mp is null || mp.type != JSONType.array)
        throw new ManifestValidationError(indexPath ~ `: "manifests" must be an array`);
    CoreIndex idx;
    foreach (i, entry; mp.array)
    {
        if (entry.type != JSONType.string || entry.str.length == 0)
            throw new ManifestValidationError(indexPath ~ ": manifests[" ~ i.to!string
                ~ "] must be a non-empty string path");
        idx.manifests ~= entry.str;
    }
    if (auto d = "description" in rec)
        if (d.type == JSONType.string)
            idx.description = d.str;
    return idx;
}

/// Default core index location relative to a repository root.
enum string defaultCoreIndexPath = buildPath("manifests", "core.index.json");

/// Resolve and load all core manifests listed in the core index under `rootDir`.
/// Every entry must set `"core": true`.
DiscoveredManifest[] discoverCoreExtensions(string rootDir, string coreIndexPath = defaultCoreIndexPath)
{
    const root = absolutePath(rootDir);
    const indexAbs = buildNormalizedPath(absolutePath(coreIndexPath, root));
    auto index = loadCoreIndex(indexAbs);
    DiscoveredManifest[] results;
    foreach (rel; index.manifests)
    {
        const manifestPath = buildNormalizedPath(absolutePath(rel, root));
        auto manifest = loadExtensionManifest(manifestPath);
        if (!manifest.core)
            throw new ManifestValidationError(manifestPath ~ `: core index entries must set "core": true`);
        results ~= DiscoveredManifest(manifest, manifestPath);
    }
    return results;
}

/// Default user-extension directory relative to a repository root.
enum string defaultUserManifestDir = buildPath("manifests", "extensions");

/// Load every `*.manifest.json` directly in `rootDir/directory` (sorted by name;
/// not recursive). A missing directory yields an empty result.
DiscoveredManifest[] discoverManifestDirectory(string rootDir, string directory = defaultUserManifestDir)
{
    const dirAbs = buildNormalizedPath(absolutePath(directory, absolutePath(rootDir)));
    if (!exists(dirAbs) || !isDir(dirAbs))
        return [];
    auto paths = dirEntries(dirAbs, "*.manifest.json", SpanMode.shallow)
        .array.sort!((a, b) => a.name < b.name);
    DiscoveredManifest[] results;
    foreach (e; paths)
    {
        const p = buildNormalizedPath(e.name);
        results ~= DiscoveredManifest(loadExtensionManifest(p), p);
    }
    return results;
}

/// Discovery result split by source.
struct Discovery
{
    DiscoveredManifest[] core; /// registered with source `core`
    DiscoveredManifest[] user; /// registered with source `manifest`
}

/// Discover under `dir`. When `dir/manifests/core.index.json` exists: the core set
/// plus `dir/manifests/extensions/*.manifest.json`. Otherwise every
/// `*.manifest.json` directly in `dir` (which must exist).
Discovery discover(string dir)
{
    Discovery d;
    if (exists(buildPath(dir, defaultCoreIndexPath)))
    {
        d.core = discoverCoreExtensions(dir);
        d.user = discoverManifestDirectory(dir);
        return d;
    }
    if (!exists(dir) || !isDir(dir))
        throw new ManifestValidationError(dir ~ ": not a directory");
    d.user = discoverManifestDirectory(dir, ".");
    return d;
}

version (unittest) package string testRepoRoot()
{
    import std.path : dirName;
    return __FILE_FULL_PATH__.dirName.dirName.dirName;
}

unittest
{
    auto found = discoverCoreExtensions(testRepoRoot);
    assert(found.length == 1);
    assert(found[0].manifest.id == "openshellorg/prohelp");
    assert(found[0].manifest.runtime == ExtensionRuntime.dub);
    assert(found[0].manifest.repository == "https://github.com/openshellorg/prohelp");
    assert(found[0].manifest.dub.package_ == "prohelp");
    assert(found[0].manifest.cli.repository == "https://github.com/openshellorg/prohelp-cli");

    assert(discoverManifestDirectory(testRepoRoot).length == 0); // manifests/extensions has only a README
    assert(discoverManifestDirectory(testRepoRoot, buildPath("manifests", "core")).length == 1);
    assert(discoverManifestDirectory(testRepoRoot, "no-such-dir").length == 0);

    auto d = discover(testRepoRoot);
    assert(d.core.length == 1 && d.user.length == 0);
    assert(discover(buildPath(testRepoRoot, "manifests", "core")).user.length == 1);
}

unittest
{
    import std.exception : assertThrown;
    import std.file : mkdirRecurse, rmdirRecurse, tempDir, write;
    import std.process : thisProcessID;

    enum x = `{"schemaVersion":1,"id":"x","name":"X","repository":"r","runtime":"cli","cli":{"binary":"x"}}`;
    auto dir = buildPath(tempDir, "sf-test-" ~ thisProcessID.to!string);
    mkdirRecurse(buildPath(dir, "manifests", "core"));
    mkdirRecurse(buildPath(dir, "manifests", "extensions"));
    scope (exit) rmdirRecurse(dir);
    write(buildPath(dir, "manifests", "core.index.json"), `{"manifests":["manifests/core/x.manifest.json"]}`);
    write(buildPath(dir, "manifests", "core", "x.manifest.json"), x);
    assertThrown!ManifestValidationError(discoverCoreExtensions(dir)); // core not set
    write(buildPath(dir, "manifests", "core", "x.manifest.json"), x[0 .. $ - 1] ~ `,"core":true}`);
    write(buildPath(dir, "manifests", "extensions", "b.manifest.json"), x.replace(`"x"`, `"b"`));
    write(buildPath(dir, "manifests", "extensions", "a.manifest.json"), x.replace(`"x"`, `"a"`));
    write(buildPath(dir, "manifests", "extensions", "ignored.json"), "{");
    auto d = discover(dir);
    assert(d.core.length == 1 && d.user.length == 2 && d.user[0].manifest.id == "a");
    write(buildPath(dir, "manifests", "core.index.json"), `{"manifests":[""]}`);
    assertThrown!ManifestValidationError(discoverCoreExtensions(dir));
    write(buildPath(dir, "manifests", "core.index.json"), `{not json`);
    assertThrown!ManifestValidationError(discoverCoreExtensions(dir));
    assertThrown!ManifestValidationError(parseExtensionManifest(`{`));
    assertThrown!ManifestValidationError(discover(buildPath(dir, "missing")));
}
