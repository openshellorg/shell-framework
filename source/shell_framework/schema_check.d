/**
 * Test-only JSON Schema subset validator used to check the shipped manifests
 * against `schemas/*.schema.json`. Supports: type, const, enum, required,
 * properties, additionalProperties (boolean), items, minLength, pattern,
 * allOf and if/then. Annotation keywords (format, description) are ignored. Compiled only in unittest builds.
 */
module shell_framework.schema_check;

version (unittest):

import std.json;
import std.conv : to;

package string[] schemaErrors(const JSONValue schema, const JSONValue v, string at = "$")
{
    string[] errs;
    if (schema.type == JSONType.true_)
        return null;
    if (auto t = "type" in schema.object)
    {
        bool ok;
        switch (t.str)
        {
            case "object": ok = v.type == JSONType.object; break;
            case "array": ok = v.type == JSONType.array; break;
            case "string": ok = v.type == JSONType.string; break;
            case "boolean": ok = v.type == JSONType.true_ || v.type == JSONType.false_; break;
            case "integer": ok = v.type == JSONType.integer || v.type == JSONType.uinteger; break;
            case "number": ok = v.type == JSONType.integer || v.type == JSONType.uinteger || v.type == JSONType.float_; break;
            default: assert(0, "unsupported type " ~ t.str);
        }
        if (!ok)
            return [at ~ ": expected " ~ t.str];
    }
    if (auto c = "const" in schema.object)
        if (*c != v)
            errs ~= at ~ ": must equal " ~ c.toString;
    if (auto en = "enum" in schema.object)
    {
        import std.algorithm : canFind;
        if (!en.array.canFind(v))
            errs ~= at ~ ": not in enum";
    }
    if (auto pat = "pattern" in schema.object)
        if (v.type == JSONType.string)
        {
            import std.regex : matchFirst, regex;
            if (matchFirst(v.str, regex(pat.str)).empty)
                errs ~= at ~ ": does not match " ~ pat.str;
        }
    if (auto all = "allOf" in schema.object)
        foreach (sub; all.array)
            errs ~= schemaErrors(sub, v, at);
    if (auto cond = "if" in schema.object)
        if (schemaErrors(*cond, v, at).length == 0)
            if (auto then = "then" in schema.object)
                errs ~= schemaErrors(*then, v, at);
    if (auto m = "minLength" in schema.object)
        if (v.str.length < m.integer)
            errs ~= at ~ ": shorter than " ~ m.integer.to!string;
    if (v.type == JSONType.object)
    {
        if (auto r = "required" in schema.object)
            foreach (k; r.array)
                if ((k.str in v.object) is null)
                    errs ~= at ~ ": missing " ~ k.str;
        const props = "properties" in schema.object;
        foreach (k, sub; v.object)
        {
            if (props !is null && (k in props.object) !is null)
                errs ~= schemaErrors(props.object[k], sub, at ~ "." ~ k);
            else if (auto ap = "additionalProperties" in schema.object)
                if (ap.type == JSONType.false_)
                    errs ~= at ~ ": unexpected property " ~ k;
        }
    }
    if (v.type == JSONType.array)
        if (auto it = "items" in schema.object)
            foreach (i, e; v.array)
                errs ~= schemaErrors(*it, e, at ~ "[" ~ i.to!string ~ "]");
    return errs;
}

unittest
{
    import std.file : readText, dirEntries, SpanMode;
    import std.path : buildPath;
    import shell_framework.discovery : testRepoRoot;

    auto root = testRepoRoot;
    auto manifestSchema = parseJSON(readText(buildPath(root, "schemas", "extension-manifest.schema.json")));
    auto indexSchema = parseJSON(readText(buildPath(root, "schemas", "core-index.schema.json")));

    size_t n;
    foreach (e; dirEntries(buildPath(root, "manifests"), "*.manifest.json", SpanMode.depth))
    {
        auto errs = schemaErrors(manifestSchema, parseJSON(readText(e.name)));
        assert(errs.length == 0, e.name ~ ": " ~ errs.to!string);
        n++;
    }
    assert(n >= 1);
    auto idx = schemaErrors(indexSchema, parseJSON(readText(buildPath(root, "manifests", "core.index.json"))));
    assert(idx.length == 0, idx.to!string);

    // the validator itself rejects bad input
    enum ok = `{"schemaVersion":1,"id":"a/b","name":"n","repository":"https://r","runtime":"cli","cli":{"binary":"b"}}`;
    assert(schemaErrors(manifestSchema, parseJSON(ok)).length == 0);
    assert(schemaErrors(manifestSchema, parseJSON(`{"id":"","name":"n"}`)).length >= 2);
    assert(schemaErrors(manifestSchema, parseJSON(ok[0 .. $ - 1] ~ `,"package":"x"}`)).length == 1);
    assert(schemaErrors(manifestSchema, parseJSON(ok[0 .. $ - 1] ~ `,"core":"yes"}`)).length == 1);
    assert(schemaErrors(manifestSchema, parseJSON(`{"schemaVersion":2,"id":"Bad","name":"n","repository":"r","runtime":"x"}`)).length == 3);
    assert(schemaErrors(manifestSchema, parseJSON(`{"schemaVersion":1,"id":"a","name":"n","repository":"r","runtime":"dub","cli":{"binary":"b"}}`)).length == 1);
}
