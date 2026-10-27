/// In-process extension registry and bootstrap.
module shell_framework.host;

import std.algorithm : filter, sort;
import std.array : array;
import std.datetime.systime : Clock;
import std.datetime.timezone : UTC;
import std.file : getcwd;
import std.path : absolutePath;

import shell_framework.types;
import shell_framework.discovery;
import shell_framework.loader;

/// Registration failed (e.g. duplicate id).
class ExtensionRegistrationError : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow @safe
    {
        super(msg, file, line);
    }
}

private string isoNow()
{
    return Clock.currTime(UTC()).toISOExtString();
}

/// In-process registry for extension manifests loaded by the host.
final class ExtensionHost
{
    private RegisteredExtension[string] extensions;
    private string delegate() now;

    /// `now` supplies registration timestamps (tests); defaults to UTC now.
    this(string delegate() now = null)
    {
        this.now = now is null ? () => isoNow() : now;
    }

    RegisteredExtension register(ExtensionManifest input, ExtensionSource source, string manifestPath = null)
    {
        auto m = validateExtensionManifest(input);
        if (m.id in extensions)
            throw new ExtensionRegistrationError("Extension already registered: " ~ m.id);
        auto r = RegisteredExtension(m, source, manifestPath, now());
        extensions[m.id] = r;
        return r;
    }

    RegisteredExtension registerFromManifestFile(ExtensionManifest m, string manifestPath,
        ExtensionSource source = ExtensionSource.manifest)
    {
        return register(m, source, manifestPath);
    }

    /// Pointer into the registry, or `null` when unknown.
    const(RegisteredExtension)* get(string id) const
    {
        return id in extensions;
    }

    bool has(string id) const nothrow
    {
        return (id in extensions) !is null;
    }

    /// All extensions sorted by id.
    RegisteredExtension[] list() const
    {
        RegisteredExtension[] l;
        foreach (v; extensions.byValue)
        {
            auto r = cast(RegisteredExtension) v;
            r.architecture.topics = v.architecture.topics.dup;
            l ~= r;
        }
        l.sort!((a, b) => a.id < b.id);
        return l;
    }

    RegisteredExtension[] listCore() const
    {
        return list().filter!(e => e.core).array;
    }

    size_t size() const nothrow @nogc @safe
    {
        return extensions.length;
    }
}

/// Options for `bootstrapExtensionHost`.
struct BootstrapOptions
{
    string rootDir; /// `null` = current working directory
    bool includeUserManifests; /// also register `manifests/extensions/*.manifest.json`
    string userManifestDir = defaultUserManifestDir;
    bool load = true; /// resolve each registered extension (PATH)
    LoadOptions loadOptions;
    string delegate() now; /// registration timestamps (tests)
}

/// Result of `bootstrapExtensionHost`.
struct BootstrappedExtensionHost
{
    ExtensionHost host;
    string rootDir;
    RegisteredExtension[] core;
    RegisteredExtension[] user;
    LoadedExtension[] loaded; /// empty when `load` is false
}

/// Create a host, register core (and optionally user) manifests, then resolve them.
BootstrappedExtensionHost bootstrapExtensionHost(BootstrapOptions options = BootstrapOptions.init)
{
    auto root = absolutePath(options.rootDir is null ? getcwd() : options.rootDir);
    auto host = new ExtensionHost(options.now);
    BootstrappedExtensionHost b;
    b.host = host;
    b.rootDir = root;
    foreach (d; discoverCoreExtensions(root))
        b.core ~= host.registerFromManifestFile(d.manifest, d.manifestPath, ExtensionSource.core);
    if (options.includeUserManifests)
        foreach (d; discoverManifestDirectory(root, options.userManifestDir))
            b.user ~= host.registerFromManifestFile(d.manifest, d.manifestPath, ExtensionSource.manifest);
    if (options.load)
        b.loaded = loadExtensions(host.list(), options.loadOptions);
    return b;
}

/// Shorthand: bootstrap `rootDir` with default options.
BootstrappedExtensionHost bootstrapExtensionHost(string rootDir, string delegate() now = null)
{
    BootstrapOptions o;
    o.rootDir = rootDir;
    o.now = now;
    return bootstrapExtensionHost(o);
}

/// Convenience constructor.
ExtensionHost createExtensionHost(string delegate() now = null)
{
    return new ExtensionHost(now);
}

unittest
{
    import std.algorithm : endsWith;

    BootstrapOptions o;
    o.rootDir = testRepoRoot;
    o.includeUserManifests = true;
    o.loadOptions.lookup = (b, p) => null;
    auto b = bootstrapExtensionHost(o);
    assert(b.core.length == 1 && b.user.length == 0 && b.host.size == 1);
    auto p = b.host.get("openshellorg/prohelp");
    assert(p !is null && p.source == ExtensionSource.core && p.core);
    assert(p.manifestPath.endsWith("prohelp.manifest.json"));
    assert(b.host.listCore.length == 1);
    assert(b.loaded.length == 1 && b.loaded[0].state == LoadState.missing);
    o.load = false;
    assert(bootstrapExtensionHost(o).loaded.length == 0);
}

unittest
{
    import std.exception : assertThrown;

    auto host = createExtensionHost(() => "2026-01-01T00:00:00.000Z");
    auto r = host.register(cliManifest("example/demo", "Demo", "https://github.com/example/demo", "demo"),
        ExtensionSource.manifest);
    assert(r.registeredAt == "2026-01-01T00:00:00.000Z");
    assertThrown!ExtensionRegistrationError(host.register(
        cliManifest("example/demo", "Demo again", "https://github.com/example/demo", "demo"), ExtensionSource.manifest));
    assertThrown!ManifestValidationError(host.register(cliManifest("", "x", "y", "z"), ExtensionSource.manifest));
    assertThrown!ManifestValidationError(host.register(cliManifest("a/b", "x", "y", null), ExtensionSource.manifest));
    host.register(cliManifest("a/first", "A", "r", "a"), ExtensionSource.manifest);
    assert(host.list[0].id == "a/first" && host.listCore.length == 0 && !host.has("nope"));
}
