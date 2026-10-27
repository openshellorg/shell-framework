/**
 * Extension loading: resolve a registered extension's CLI on PATH and spawn it.
 * The host never compiles D; `dub build` the extension upstream first.
 */
module shell_framework.loader;

import std.algorithm : map, splitter;
import std.array : array;
import std.file : exists, isFile;
import std.path : buildPath, pathSeparator;
import std.process : environment;
import std.string : toLower;

import shell_framework.types;

/// Outcome of `loadExtension`.
enum LoadState
{
    resolved,
    missing,
    notApplicable, /// JSON/C spelling: "not-applicable"
}

/// A registered extension plus its resolved load surface.
struct LoadedExtension
{
    RegisteredExtension registered;
    LoadState state;
    string binaryPath; /// set when `resolved` via PATH
    string dubPackage; /// `dub.package` when the manifest has one
    string reason;
}

/// Options for PATH resolution and loading.
struct LoadOptions
{
    /// When false, only validate manifest shape and skip PATH lookup.
    bool resolve = true;
    /// PATH override; `null` uses the process environment.
    string pathEnv;
    /// Test hook: map binary name to a path (skips the real PATH walk).
    string delegate(string binary, string pathEnv) lookup;
}

private bool isExecutableFile(string p)
{
    try
    {
        if (!exists(p) || !isFile(p))
            return false;
        version (Posix)
        {
            import core.sys.posix.unistd : access, X_OK;
            import std.string : toStringz;

            return access(p.toStringz, X_OK) == 0;
        }
        else
            return true;
    }
    catch (Exception)
        return false;
}

/// Resolve a command name on PATH (PATHEXT honoured on Windows). `null` when absent.
string resolveBinaryOnPath(string binary, LoadOptions options = LoadOptions.init)
{
    string pathEnv = options.pathEnv;
    if (pathEnv is null)
        pathEnv = environment.get("PATH", environment.get("Path", ""));
    if (options.lookup !is null)
        return options.lookup(binary, pathEnv);
    version (Windows)
        auto exts = environment.get("PATHEXT", ".EXE;.CMD;.BAT;.COM").splitter(';').map!toLower.array;
    else
        auto exts = [""];
    foreach (dir; pathEnv.splitter(pathSeparator))
    {
        if (dir.length == 0)
            continue;
        foreach (ext; exts)
        {
            const candidate = buildPath(dir, binary ~ ext);
            if (isExecutableFile(candidate))
                return candidate;
        }
    }
    return null;
}

/// Resolve the install surface for one registered extension (does not spawn).
/// `node` runtimes are reported as `notApplicable`: the D host does not embed
/// a JavaScript engine (a Node binding over the C ABI is planned work).
LoadedExtension loadExtension(RegisteredExtension registered, LoadOptions options = LoadOptions.init)
{
    LoadedExtension l;
    l.registered = registered;
    if (registered.hasDub)
        l.dubPackage = registered.dub.package_;
    if (!options.resolve)
    {
        l.state = LoadState.notApplicable;
        l.reason = "resolve disabled";
        return l;
    }
    if (registered.runtime == ExtensionRuntime.node)
    {
        l.state = LoadState.notApplicable;
        l.reason = "node runtime is not loaded by the D host (entry " ~ registered.node.entry ~ ")";
        return l;
    }
    const binary = registered.cliBinaryName;
    if (binary is null)
    {
        l.state = LoadState.missing;
        l.reason = "no cli.binary configured";
        return l;
    }
    l.binaryPath = resolveBinaryOnPath(binary, options);
    if (l.binaryPath is null)
    {
        string hint;
        if (registered.runtime == ExtensionRuntime.dub && registered.hasDub)
        {
            hint = ` (build with dub: package "` ~ registered.dub.package_ ~ `"`;
            if (registered.dub.configuration !is null)
                hint ~= `, configuration "` ~ registered.dub.configuration ~ `"`;
            hint ~= ")";
        }
        l.state = LoadState.missing;
        l.reason = `binary "` ~ binary ~ `" not found on PATH` ~ hint;
        return l;
    }
    l.state = LoadState.resolved;
    l.reason = "resolved " ~ binary;
    return l;
}

/// `loadExtension` over a list, in order.
LoadedExtension[] loadExtensions(RegisteredExtension[] registered, LoadOptions options = LoadOptions.init)
{
    LoadedExtension[] result;
    foreach (r; registered)
        result ~= loadExtension(r, options);
    return result;
}

/// Thrown when a CLI cannot be spawned or times out.
class ExtensionRunError : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow @safe
    {
        super(msg, file, line);
    }
}

/// Options for `runExtensionCli`.
struct RunCliOptions
{
    string[] args;
    string cwd;
    string[string] env; /// merged over the inherited environment
    long timeoutMs; /// <= 0 means no timeout
}

/// Exit code and captured streams.
struct CliResult
{
    int code;
    string stdout;
    string stderr;
}

/// Spawn the extension CLI (must be `resolved`). Output is captured via temp
/// files so large output cannot deadlock the pipes.
CliResult runExtensionCli(const LoadedExtension loaded, RunCliOptions options = RunCliOptions.init)
{
    import core.thread : Thread;
    import core.time : msecs, MonoTime;
    import std.conv : to;
    import std.exception : collectException;
    import std.file : readText, remove, tempDir;
    import std.process : Config, kill, spawnProcess, thisProcessID, tryWait, wait;
    import std.stdio : File;
    import std.uuid : randomUUID;

    if (loaded.state != LoadState.resolved || loaded.binaryPath is null)
        throw new ExtensionRunError(loaded.reason !is null ? loaded.reason
            : "Extension " ~ loaded.registered.id ~ " is not resolved for CLI spawn");

    const stem = buildPath(tempDir, "sf-run-" ~ thisProcessID.to!string ~ "-" ~ randomUUID.toString);
    const outPath = stem ~ ".out", errPath = stem ~ ".err";
    scope (exit)
    {
        foreach (p; [outPath, errPath])
            collectException(remove(p));
    }
    int code;
    {
        auto outF = File(outPath, "wb"), errF = File(errPath, "wb");
        version (Windows)
            enum nullDevice = "NUL";
        else
            enum nullDevice = "/dev/null";
        auto devNull = File(nullDevice, "rb");
        auto pid = spawnProcess([cast(string) loaded.binaryPath] ~ options.args, devNull, outF, errF,
            options.env, Config.none, options.cwd);
        if (options.timeoutMs > 0)
        {
            const deadline = MonoTime.currTime + options.timeoutMs.msecs;
            for (;;)
            {
                auto r = tryWait(pid);
                if (r.terminated)
                {
                    code = r.status;
                    break;
                }
                if (MonoTime.currTime >= deadline)
                {
                    kill(pid);
                    wait(pid);
                    throw new ExtensionRunError("CLI timed out after " ~ options.timeoutMs.to!string ~ "ms");
                }
                Thread.sleep(10.msecs);
            }
        }
        else
            code = wait(pid);
    }
    return CliResult(code, readText(outPath), readText(errPath));
}

unittest
{
    import std.algorithm : canFind;
    import std.exception : assertThrown;

    auto dubM = validateExtensionManifest(cliManifest("x/p", "P", "r", "prohelp"));
    dubM.runtime = ExtensionRuntime.dub;
    dubM.hasDub = true;
    dubM.dub.package_ = "prohelp";
    dubM.dub.configuration = "executable";
    auto reg = RegisteredExtension(dubM, ExtensionSource.core, null, "t");

    LoadOptions none;
    none.lookup = (b, p) => null;
    auto miss = loadExtension(reg, none);
    assert(miss.state == LoadState.missing && miss.dubPackage == "prohelp");
    assert(miss.reason == `binary "prohelp" not found on PATH (build with dub: package "prohelp", configuration "executable")`);
    assertThrown!ExtensionRunError(runExtensionCli(miss));

    LoadOptions found;
    found.lookup = (b, p) => "/opt/bin/" ~ b;
    auto ok = loadExtension(reg, found);
    assert(ok.state == LoadState.resolved && ok.binaryPath == "/opt/bin/prohelp" && ok.reason == "resolved prohelp");

    LoadOptions off;
    off.resolve = false;
    assert(loadExtension(reg, off).state == LoadState.notApplicable);

    ExtensionManifest nodeM;
    nodeM.id = "n"; nodeM.name = "n"; nodeM.repository = "r";
    nodeM.runtime = ExtensionRuntime.node; nodeM.hasNode = true; nodeM.node.entry = "node:os";
    auto n = loadExtension(RegisteredExtension(nodeM, ExtensionSource.manifest, null, "t"));
    assert(n.state == LoadState.notApplicable && n.reason.canFind("node:os"));

    LoadOptions empty;
    empty.pathEnv = "";
    assert(resolveBinaryOnPath("definitely-not-a-binary-sf", empty) is null);
}

unittest
{
    // Real spawn through PATH resolution: a shell that exists on every CI runner.
    version (Windows)
        enum bin = "cmd", args = ["/c", "echo hello& echo oops 1>&2& exit 3"];
    else
        enum bin = "sh", args = ["-c", "echo hello; echo oops >&2; exit 3"];
    auto reg = RegisteredExtension(validateExtensionManifest(cliManifest("t/sh", "sh", "r", bin)),
        ExtensionSource.manifest, null, "t");
    auto l = loadExtension(reg);
    assert(l.state == LoadState.resolved, l.reason);
    RunCliOptions o;
    o.args = args.dup;
    o.timeoutMs = 20_000;
    auto r = runExtensionCli(l, o);
    import std.string : strip;
    assert(r.code == 3 && r.stdout.strip == "hello" && r.stderr.strip == "oops");

    version (Posix)
    {
        import std.exception : assertThrown;

        o.args = ["-c", "sleep 5"];
        o.timeoutMs = 100;
        assertThrown!ExtensionRunError(runExtensionCli(l, o));
    }
}
