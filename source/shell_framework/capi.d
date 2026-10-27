/**
 * C ABI for shell-framework. Header: `include/shell_framework.h`.
 *
 * Ownership rules (also documented in the header):
 * $(UL
 *  $(LI `sf_host_create` returns a handle owned by the caller; release it with
 *       `sf_host_destroy`. Create also initializes the D runtime (reference
 *       counted); destroy releases that reference.)
 *  $(LI Strings returned through `sf_extension_info` and `sf_last_error` are
 *       owned by the host. Do not free them. Info strings stay valid until the
 *       host is destroyed; `sf_last_error` stays valid until the next call on
 *       that host.)
 *  $(LI Pointers returned by `sf_extension_to_json` are heap memory owned by
 *       the caller; release them with `sf_free` (never with another allocator).)
 *  $(LI A host is not thread-safe. Use it from the thread that created it, or
 *       serialize access and register foreign threads with the D runtime.)
 * )
 */
module shell_framework.capi;

import core.memory : GC;
import core.runtime : Runtime;
import core.stdc.stdlib : malloc, free;
import core.stdc.string : memcpy;
import std.json : JSONOptions;

import shell_framework;

version (SF_SharedLib) version (Windows)
{
    import core.sys.windows.dll : SimpleDllMain;
    mixin SimpleDllMain;
}

/// Status codes.
enum : int
{
    SF_OK = 0,
    SF_ERROR = -1,
}

/// Mirrors `sf_extension_info` in the header. Absent optional strings are NULL.
extern (C) struct sf_extension_info
{
    const(char)* id;
    const(char)* name;
    const(char)* repository;
    const(char)* version_;
    int core;
    const(char)* runtime; /// "dub", "node" or "cli"
    const(char)* dub_package;
    const(char)* dub_configuration;
    const(char)* dub_binary;
    const(char)* node_entry;
    const(char)* cli_repository;
    const(char)* cli_binary;
    const(char)* architecture_doc;
    int source; /// 0 = core, 1 = manifest
    const(char)* manifest_path;
    const(char)* registered_at;
}

/// Mirrors `sf_load_info` in the header.
extern (C) struct sf_load_info
{
    int state; /// 0 = resolved, 1 = missing, 2 = not applicable
    const(char)* binary_path;
    const(char)* dub_package;
    const(char)* reason;
}

/// Opaque handle (C: `typedef struct sf_host sf_host;`).
extern (C) struct sf_host;

private final class HostState
{
    ExtensionHost host;
    string lastError; // NUL-terminated by construction
    LoadedExtension lastLoad; // keeps sf_load_info strings alive
    sf_load_info lastLoadInfo;
    sf_extension_info[] cache;
    bool cacheValid;

    this()
    {
        host = new ExtensionHost();
    }

    void fail(string msg) nothrow
    {
        lastError = (msg ~ '\0');
    }

    void rebuildCache()
    {
        if (cacheValid)
            return;
        static const(char)* z(string s)
        {
            return s is null ? null : (s ~ '\0').ptr;
        }

        import std.conv : to;

        cache = null;
        foreach (e; host.list())
        {
            sf_extension_info i;
            i.id = z(e.id);
            i.name = z(e.name);
            i.repository = z(e.repository);
            i.version_ = z(e.version_);
            i.core = e.core ? 1 : 0;
            i.runtime = z(e.runtime.to!string);
            i.dub_package = e.hasDub ? z(e.dub.package_) : null;
            i.dub_configuration = e.hasDub ? z(e.dub.configuration) : null;
            i.dub_binary = e.hasDub ? z(e.dub.binary) : null;
            i.node_entry = e.hasNode ? z(e.node.entry) : null;
            i.architecture_doc = e.hasArchitecture ? z(e.architecture.doc) : null;
            i.cli_repository = e.hasCli ? z(e.cli.repository) : null;
            i.cli_binary = e.hasCli ? z(e.cli.binary) : null;
            i.source = e.source == ExtensionSource.core ? 0 : 1;
            i.manifest_path = z(e.manifestPath);
            i.registered_at = z(e.registeredAt);
            cache ~= i;
        }
        cacheValid = true;
    }
}

private string globalError = "\0"; // thread-local: errors with no host (create failure, NULL host)

private HostState state(sf_host* h) nothrow
{
    return cast(HostState) cast(void*) h;
}

private int guarded(sf_host* h, scope int delegate(HostState) body_) nothrow
{
    auto s = state(h);
    if (s is null)
    {
        globalError = "sf_host is NULL\0";
        return SF_ERROR;
    }
    try
    {
        s.lastError = "\0";
        return body_(s);
    }
    catch (Exception e)
    {
        s.fail(e.msg);
        return SF_ERROR;
    }
}

private string str(const(char)* p) nothrow
{
    import std.string : fromStringz;
    return p is null ? null : fromStringz(p).idup;
}

extern (C) nothrow
{

/// Library version string (static; never free).
export const(char)* sf_version()
{
    return shellFrameworkVersion.ptr; // string literals are NUL-terminated
}

/// Initialize the D runtime (ref-counted) and create an empty host. NULL on failure.
export sf_host* sf_host_create()
{
    try
    {
        if (!Runtime.initialize())
        {
            globalError = "D runtime initialization failed\0";
            return null;
        }
        auto s = new HostState();
        GC.addRoot(cast(void*) s);
        GC.setAttr(cast(void*) s, GC.BlkAttr.NO_MOVE);
        return cast(sf_host*) cast(void*) s;
    }
    catch (Throwable t)
    {
        globalError = "sf_host_create failed\0";
        return null;
    }
}

/// Destroy a host (NULL is a no-op) and release one D runtime reference.
export void sf_host_destroy(sf_host* h)
{
    if (h is null)
        return;
    try
    {
        GC.removeRoot(cast(void*) h);
        Runtime.terminate();
    }
    catch (Throwable)
    {
    }
}

/// Load one manifest file and register it (source = manifest).
export int sf_load_manifest_file(sf_host* h, const(char)* path)
{
    return guarded(h, (s) {
        auto p = str(path);
        if (p is null)
            throw new Exception("path is NULL");
        s.host.registerFromManifestFile(loadExtensionManifest(p), p);
        s.cacheValid = false;
        return SF_OK;
    });
}

/// Parse `len` bytes of manifest JSON (need not be NUL-terminated) and register it.
export int sf_load_manifest_json(sf_host* h, const(char)* json, size_t len)
{
    return guarded(h, (s) {
        if (json is null)
            throw new Exception("json is NULL");
        auto text = json[0 .. len].idup;
        s.host.register(parseExtensionManifest(text), ExtensionSource.manifest);
        s.cacheValid = false;
        return SF_OK;
    });
}

/// Discover under `dir` and register what is found. When `dir/manifests/core.index.json`
/// exists: the core set (source = core) plus `dir/manifests/extensions/*.manifest.json`
/// (source = manifest). Otherwise every `*.manifest.json` directly in `dir`
/// (source = manifest). Returns the number registered, or SF_ERROR. Nothing is
/// registered if loading fails; a duplicate id during registration stops at
/// that entry (earlier entries stay registered).
export int sf_discover(sf_host* h, const(char)* dir)
{
    return guarded(h, (s) {
        auto d = str(dir);
        if (d is null)
            throw new Exception("dir is NULL");
        auto found = discover(d);
        int n;
        scope (exit) s.cacheValid = false;
        foreach (f; found.core)
        {
            s.host.registerFromManifestFile(f.manifest, f.manifestPath, ExtensionSource.core);
            n++;
        }
        foreach (f; found.user)
        {
            s.host.registerFromManifestFile(f.manifest, f.manifestPath, ExtensionSource.manifest);
            n++;
        }
        return n;
    });
}

/// Number of registered extensions (0 for NULL).
export size_t sf_extension_count(sf_host* h)
{
    auto s = state(h);
    return s is null ? 0 : s.host.size();
}

/// Fill `out_` with extension `index` (sorted by id). Strings are host-owned.
export int sf_extension_get(sf_host* h, size_t index, sf_extension_info* out_)
{
    return guarded(h, (s) {
        if (out_ is null)
            throw new Exception("out is NULL");
        s.rebuildCache();
        if (index >= s.cache.length)
            throw new Exception("index out of range");
        *out_ = s.cache[index];
        return SF_OK;
    });
}

/// Extension `index` as manifest JSON (malloc'd, NUL-terminated). Free with `sf_free`. NULL on error.
export char* sf_extension_to_json(sf_host* h, size_t index)
{
    char* result;
    guarded(h, (s) {
        auto l = s.host.list();
        if (index >= l.length)
            throw new Exception("index out of range");
        auto text = l[index].manifest.toJSON().toString(JSONOptions.doNotEscapeSlashes);
        result = cast(char*) malloc(text.length + 1);
        if (result is null)
            throw new Exception("out of memory");
        memcpy(result, text.ptr, text.length);
        result[text.length] = 0;
        return SF_OK;
    });
    return result;
}

/// Resolve extension `index` on PATH (does not spawn). `out_` strings are host-owned
/// and stay valid until the next `sf_extension_load` on this host.
export int sf_extension_load(sf_host* h, size_t index, sf_load_info* out_)
{
    return guarded(h, (s) {
        if (out_ is null)
            throw new Exception("out is NULL");
        auto l = s.host.list();
        if (index >= l.length)
            throw new Exception("index out of range");
        static const(char)* z(string v)
        {
            return v is null ? null : (v ~ '\0').ptr;
        }

        s.lastLoad = loadExtension(l[index]);
        with (s.lastLoadInfo)
        {
            state = cast(int) s.lastLoad.state;
            binary_path = z(s.lastLoad.binaryPath);
            dub_package = z(s.lastLoad.dubPackage);
            reason = z(s.lastLoad.reason);
        }
        *out_ = s.lastLoadInfo;
        return SF_OK;
    });
}

/// Last error for `h` (or the thread's host-less error when `h` is NULL).
/// Empty string when the last call succeeded. Host-owned; do not free.
export const(char)* sf_last_error(sf_host* h)
{
    auto s = state(h);
    return s is null ? globalError.ptr : s.lastError.ptr;
}

/// Free memory returned by this library as caller-owned (`sf_extension_to_json`). NULL is a no-op.
export void sf_free(void* p)
{
    free(p);
}

} // extern (C) nothrow

unittest
{
    import std.string : fromStringz, toStringz;
    import std.path : buildPath;
    import shell_framework.discovery : testRepoRoot;

    auto h = sf_host_create();
    assert(h !is null);
    scope (exit) sf_host_destroy(h);
    assert(fromStringz(sf_version()) == shellFrameworkVersion);

    assert(sf_discover(h, testRepoRoot.toStringz) == 1);
    assert(sf_extension_count(h) == 1);
    sf_extension_info info;
    assert(sf_extension_get(h, 0, &info) == SF_OK);
    assert(fromStringz(info.id) == "openshellorg/prohelp" && info.core == 1 && info.source == 0);
    assert(fromStringz(info.cli_binary) == "prohelp");
    assert(sf_extension_get(h, 5, &info) == SF_ERROR && fromStringz(sf_last_error(h)).length > 0);

    assert(fromStringz(info.runtime) == "dub" && fromStringz(info.dub_package) == "prohelp");
    assert(fromStringz(info.dub_configuration) == "executable" && info.node_entry is null);

    enum j = `{"schemaVersion":1,"id":"example/demo","name":"Demo","repository":"https://github.com/example/demo","runtime":"node","node":{"entry":"demo"}}xyz`;
    assert(sf_load_manifest_json(h, j.ptr, j.length - 3) == SF_OK);
    assert(fromStringz(sf_last_error(h)) == "");
    assert(sf_load_manifest_json(h, j.ptr, j.length - 3) == SF_ERROR); // duplicate
    assert(sf_load_manifest_json(h, "{".ptr, 1) == SF_ERROR);
    assert(sf_extension_count(h) == 2);
    assert(sf_extension_get(h, 0, &info) == SF_OK && fromStringz(info.id) == "example/demo");
    assert(info.version_ is null && info.manifest_path is null && fromStringz(info.node_entry) == "demo");

    sf_load_info li;
    assert(sf_extension_load(h, 0, &li) == SF_OK && li.state == 2);
    assert(sf_extension_load(h, 9, &li) == SF_ERROR);

    import std.json : parseJSON;
    auto js = sf_extension_to_json(h, 1);
    assert(js !is null);
    auto parsed = parseJSON(fromStringz(js));
    assert(parsed["id"].str == "openshellorg/prohelp" && parsed["dub"]["package"].str == "prohelp");
    assert(parsed["runtime"].str == "dub" && parsed["architecture"]["topics"].array.length == 2);
    sf_free(js);

    assert(sf_load_manifest_file(h, buildPath(testRepoRoot, "manifests", "core", "prohelp.manifest.json").toStringz) == SF_ERROR);
    assert(sf_load_manifest_file(null, null) == SF_ERROR && fromStringz(sf_last_error(null)) == "sf_host is NULL");
}
