/**
 * Extension manifest types and validation (manifest schema v1).
 * Pointers only - no vendored extension source in shell-framework.
 *
 * Canon context: https://github.com/openshellorg/shell-architecture
 */
module shell_framework.types;

import std.conv : to;
import std.json;

/// Thrown when a manifest or core index is malformed.
class ManifestValidationError : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow @safe
    {
        super(msg, file, line);
    }
}

/// Primary load surface. JSON values: "dub", "node", "cli".
enum ExtensionRuntime
{
    dub,
    node,
    cli,
}

/// `dub` block. Absent optional strings are `null`.
struct ExtensionDubManifest
{
    string package_; /// JSON key `package` (required inside `dub`)
    string configuration;
    string binary;
}

/// `node` block.
struct ExtensionNodeManifest
{
    string entry;
}

/// `cli` block.
struct ExtensionCliManifest
{
    string repository;
    string binary;
}

/// `architecture` block (links into shell-architecture).
struct ExtensionArchitectureLinks
{
    string doc;
    string[] topics;
}

/// Extension manifest as loaded from JSON on disk.
/// Optional strings are `null` when absent; `hasX` flags mark optional blocks.
struct ExtensionManifest
{
    int schemaVersion = 1;
    string schemaUrl; /// JSON key `$schema`
    string id;
    string name;
    string repository;
    string version_; /// JSON key `version`
    bool core;
    ExtensionRuntime runtime;
    bool hasDub;
    ExtensionDubManifest dub;
    bool hasNode;
    ExtensionNodeManifest node;
    bool hasCli;
    ExtensionCliManifest cli;
    bool hasArchitecture;
    ExtensionArchitectureLinks architecture;

    /// Serialize back to the manifest JSON shape (absent fields omitted).
    JSONValue toJSON() const
    {
        static JSONValue obj()
        {
            return JSONValue(string[string].init);
        }

        auto j = obj();
        if (schemaUrl !is null) j["$schema"] = schemaUrl;
        j["schemaVersion"] = schemaVersion;
        j["id"] = id;
        j["name"] = name;
        j["repository"] = repository;
        if (version_ !is null) j["version"] = version_;
        if (core) j["core"] = true;
        j["runtime"] = runtime.to!string;
        if (hasDub)
        {
            auto d = obj();
            d["package"] = dub.package_;
            if (dub.configuration !is null) d["configuration"] = dub.configuration;
            if (dub.binary !is null) d["binary"] = dub.binary;
            j["dub"] = d;
        }
        if (hasNode)
        {
            auto n = obj();
            n["entry"] = node.entry;
            j["node"] = n;
        }
        if (hasCli)
        {
            auto c = obj();
            if (cli.repository !is null) c["repository"] = cli.repository;
            if (cli.binary !is null) c["binary"] = cli.binary;
            j["cli"] = c;
        }
        if (hasArchitecture)
        {
            auto a = obj();
            if (architecture.doc !is null) a["doc"] = architecture.doc;
            if (architecture.topics !is null) a["topics"] = JSONValue(architecture.topics.dup);
            j["architecture"] = a;
        }
        return j;
    }

    /// CLI binary used for PATH resolution (`cli.binary`, else `dub.binary`).
    string cliBinaryName() const
    {
        if (hasCli && cli.binary !is null) return cli.binary;
        if (hasDub && dub.binary !is null) return dub.binary;
        return null;
    }
}

/// Core index (`manifests/core.index.json`).
struct CoreIndex
{
    string description;
    string[] manifests;
}

/// Where a registered extension came from.
enum ExtensionSource
{
    core,
    manifest,
}

/// A manifest after registration in an `ExtensionHost`.
struct RegisteredExtension
{
    ExtensionManifest manifest;
    alias manifest this;
    ExtensionSource source;
    string manifestPath; /// `null` when registered from memory
    string registeredAt; /// ISO-8601 timestamp
}

private alias Rec = const(JSONValue[string]);

/// Absent or JSON null -> null (or error when required); otherwise must be a non-empty string.
private string readString(Rec rec, string key, string label, bool required = false)
{
    auto p = key in rec;
    if (p is null || p.type == JSONType.null_)
    {
        if (required)
            throw new ManifestValidationError(label ~ `: "` ~ key ~ `" is required`);
        return null;
    }
    if (p.type != JSONType.string || p.str.length == 0)
        throw new ManifestValidationError(label ~ `: "` ~ key ~ `" must be a non-empty string`);
    return p.str;
}

/// Absent or null -> null; object -> the value; anything else -> error.
private const(JSONValue)* readObject(Rec rec, string key, string label)
{
    auto p = key in rec;
    if (p is null || p.type == JSONType.null_)
        return null;
    if (p.type != JSONType.object)
        throw new ManifestValidationError(label ~ ": expected an object");
    return p;
}

/// Validate a parsed JSON value as a schema-v1 extension manifest.
ExtensionManifest validateExtensionManifest(const JSONValue value, string label = "manifest")
{
    if (value.type != JSONType.object)
        throw new ManifestValidationError(label ~ ": expected an object");
    Rec rec = value.object;

    auto sv = "schemaVersion" in rec;
    const isOne = sv !is null && ((sv.type == JSONType.integer && sv.integer == 1)
        || (sv.type == JSONType.uinteger && sv.uinteger == 1));
    if (!isOne)
        throw new ManifestValidationError(label ~ `: "schemaVersion" must be 1 (got `
            ~ (sv is null ? "undefined" : sv.toString()) ~ ")");

    ExtensionManifest m;
    m.id = readString(rec, "id", label, true);
    m.name = readString(rec, "name", label, true);
    m.repository = readString(rec, "repository", label, true);
    const runtimeRaw = readString(rec, "runtime", label, true);
    switch (runtimeRaw)
    {
        case "dub": m.runtime = ExtensionRuntime.dub; break;
        case "node": m.runtime = ExtensionRuntime.node; break;
        case "cli": m.runtime = ExtensionRuntime.cli; break;
        default: throw new ManifestValidationError(label ~ `: "runtime" must be one of: dub, node, cli`);
    }
    m.schemaUrl = readString(rec, "$schema", label);
    m.version_ = readString(rec, "version", label);
    if (auto c = "core" in rec)
        m.core = c.type == JSONType.true_;

    if (auto o = readObject(rec, "dub", label ~ ".dub"))
    {
        Rec sub = o.object;
        m.hasDub = true;
        m.dub.package_ = readString(sub, "package", label ~ ".dub", true);
        m.dub.configuration = readString(sub, "configuration", label ~ ".dub");
        m.dub.binary = readString(sub, "binary", label ~ ".dub");
    }
    if (auto o = readObject(rec, "node", label ~ ".node"))
    {
        Rec sub = o.object;
        m.hasNode = true;
        m.node.entry = readString(sub, "entry", label ~ ".node", true);
    }
    if (auto o = readObject(rec, "cli", label ~ ".cli"))
    {
        Rec sub = o.object;
        m.hasCli = true;
        m.cli.repository = readString(sub, "repository", label ~ ".cli");
        m.cli.binary = readString(sub, "binary", label ~ ".cli");
    }
    if (auto o = readObject(rec, "architecture", label ~ ".architecture"))
    {
        Rec sub = o.object;
        m.hasArchitecture = true;
        m.architecture.doc = readString(sub, "doc", label ~ ".architecture");
        if (auto t = "topics" in sub)
            if (t.type == JSONType.array)
            {
                m.architecture.topics = [];
                foreach (i, topic; t.array)
                {
                    if (topic.type != JSONType.string || topic.str.length == 0)
                        throw new ManifestValidationError(label ~ ".architecture.topics[" ~ i.to!string
                            ~ "] must be a non-empty string");
                    m.architecture.topics ~= topic.str;
                }
            }
    }
    return checkRuntimeRules(m, label);
}

private ExtensionManifest checkRuntimeRules(ExtensionManifest m, string label)
{
    final switch (m.runtime)
    {
        case ExtensionRuntime.dub:
            if (!m.hasDub)
                throw new ManifestValidationError(label ~ `: dub runtime requires "dub"`);
            if (!m.hasCli || m.cli.binary is null)
                throw new ManifestValidationError(label ~ ": dub runtime requires cli.binary for PATH resolution");
            break;
        case ExtensionRuntime.cli:
            if (!m.hasCli || m.cli.binary is null)
                throw new ManifestValidationError(label ~ ": cli runtime requires cli.binary");
            break;
        case ExtensionRuntime.node:
            if (!m.hasNode || m.node.entry.length == 0)
                throw new ManifestValidationError(label ~ ": node runtime requires node.entry");
            break;
    }
    return m;
}

/// Validate an already-typed manifest (required fields and runtime rules).
ExtensionManifest validateExtensionManifest(const ExtensionManifest input, string label = "manifest")
{
    ExtensionManifest m = cast(ExtensionManifest) input;
    if (m.schemaVersion != 1)
        throw new ManifestValidationError(label ~ `: "schemaVersion" must be 1`);
    foreach (pair; [["id", m.id], ["name", m.name], ["repository", m.repository]])
        if (pair[1].length == 0)
            throw new ManifestValidationError(label ~ `: "` ~ pair[0] ~ `" must be a non-empty string`);
    return checkRuntimeRules(m, label);
}

/// Build a `cli`-runtime manifest in code (tests, embedders).
ExtensionManifest cliManifest(string id, string name, string repository, string binary)
{
    ExtensionManifest m;
    m.id = id;
    m.name = name;
    m.repository = repository;
    m.runtime = ExtensionRuntime.cli;
    m.hasCli = true;
    m.cli.binary = binary;
    return m;
}

unittest
{
    import std.exception : assertThrown, collectExceptionMsg;
    import std.algorithm : canFind;

    auto m = validateExtensionManifest(parseJSON(`{"schemaVersion":1,"id":"a/b","name":"B","repository":"https://x/b",
        "version":"1.0.0","core":true,"runtime":"dub","dub":{"package":"b","configuration":"executable"},
        "cli":{"binary":"b"},"architecture":{"doc":"https://d","topics":["t1"]}}`));
    assert(m.id == "a/b" && m.core && m.runtime == ExtensionRuntime.dub && m.dub.package_ == "b");
    assert(m.dub.binary is null && m.cliBinaryName == "b" && m.architecture.topics == ["t1"]);
    auto round = validateExtensionManifest(m.toJSON());
    assert(round == m);

    void bad(string json, string needle)
    {
        auto msg = collectExceptionMsg!ManifestValidationError(validateExtensionManifest(parseJSON(json)));
        assert(msg !is null && msg.canFind(needle), json ~ " -> " ~ msg);
    }

    bad(`[]`, "expected an object");
    bad(`{"id":"i","name":"n","repository":"r","runtime":"cli","cli":{"binary":"x"}}`, "schemaVersion");
    bad(`{"schemaVersion":2,"id":"i","name":"n","repository":"r","runtime":"cli","cli":{"binary":"x"}}`, "(got 2)");
    bad(`{"schemaVersion":1,"id":"","name":"n","repository":"r","runtime":"cli"}`, `"id" must be`);
    bad(`{"schemaVersion":1,"name":"n","repository":"r","runtime":"cli"}`, `"id" is required`);
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"python"}`, "one of");
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"dub","cli":{"binary":"x"}}`, `requires "dub"`);
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"dub","dub":{"package":"p"}}`, "cli.binary");
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"cli"}`, "cli runtime requires");
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"node"}`, "node.entry");
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"cli","cli":[]}`, "expected an object");
    bad(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"cli","cli":{"binary":"x"},"architecture":{"topics":[""]}}`, "topics[0]");
    assert(validateExtensionManifest(parseJSON(`{"schemaVersion":1,"id":"i","name":"n","repository":"r","runtime":"node","node":{"entry":"node:os"}}`)).node.entry == "node:os");
    assertThrown!ManifestValidationError(validateExtensionManifest(cliManifest("i", "n", "r", null)));
}
