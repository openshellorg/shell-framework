/*
 * shell_framework.h - C ABI for OpenShellOrg shell-framework (D core).
 * Hand-written; must match source/shell_framework/capi.d.
 *
 * OWNERSHIP RULES
 *  - sf_host_create() returns a handle owned by the caller. Release it with
 *    sf_host_destroy(). Create initializes the D runtime (reference counted);
 *    destroy releases that reference. Pair every create with one destroy.
 *  - Strings reached through sf_extension_info and sf_last_error() are owned by
 *    the host. Never free them. Info strings stay valid until the host is
 *    destroyed. sf_last_error() stays valid until the next call on that host.
 *  - sf_extension_to_json() returns caller-owned memory. Release it with
 *    sf_free(), never with your own free().
 *  - sf_version() returns a static string.
 *  - A host is not thread-safe: use it from the thread that created it.
 *
 * ERRORS
 *  Functions returning int return SF_OK (0) or a count on success and
 *  SF_ERROR (-1) on failure; read sf_last_error(host) for the message.
 *  Errors without a host (create failure, NULL host) are read with
 *  sf_last_error(NULL).
 */
#ifndef SHELL_FRAMEWORK_H
#define SHELL_FRAMEWORK_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) && !defined(SF_STATIC)
#  define SF_API __declspec(dllimport)
#else
#  define SF_API
#endif

#define SF_OK 0
#define SF_ERROR (-1)

#define SF_SOURCE_CORE 0
#define SF_SOURCE_MANIFEST 1

#define SF_LOAD_RESOLVED 0
#define SF_LOAD_MISSING 1
#define SF_LOAD_NOT_APPLICABLE 2

typedef struct sf_host sf_host;

/* Absent optional strings are NULL. */
typedef struct sf_extension_info {
    const char *id;
    const char *name;
    const char *repository;
    const char *version;
    int core;                  /* 1 when "core": true */
    const char *runtime;       /* "dub", "node" or "cli" */
    const char *dub_package;
    const char *dub_configuration;
    const char *dub_binary;
    const char *node_entry;
    const char *cli_repository;
    const char *cli_binary;
    const char *architecture_doc;
    int source;                /* SF_SOURCE_CORE or SF_SOURCE_MANIFEST */
    const char *manifest_path; /* NULL when loaded from memory */
    const char *registered_at; /* ISO-8601 UTC */
} sf_extension_info;

/* Result of sf_extension_load. Strings are host-owned and stay valid until the
 * next sf_extension_load call on the same host. */
typedef struct sf_load_info {
    int state;               /* SF_LOAD_* */
    const char *binary_path; /* set when SF_LOAD_RESOLVED */
    const char *dub_package; /* dub.package when present */
    const char *reason;      /* e.g. dub build hint when missing */
} sf_load_info;

SF_API const char *sf_version(void);

SF_API sf_host *sf_host_create(void);
SF_API void sf_host_destroy(sf_host *host);

/* Register one manifest file (source = manifest). */
SF_API int sf_load_manifest_file(sf_host *host, const char *path);
/* Register manifest JSON of len bytes (need not be NUL-terminated). */
SF_API int sf_load_manifest_json(sf_host *host, const char *json, size_t len);
/* dir/manifests/core.index.json present: register the core set (source = core)
 * plus dir/manifests/extensions/\*.manifest.json (source = manifest).
 * Otherwise register every *.manifest.json directly in dir.
 * Returns the count registered or SF_ERROR. */
SF_API int sf_discover(sf_host *host, const char *dir);

SF_API size_t sf_extension_count(sf_host *host);
/* Extensions are ordered by id. */
SF_API int sf_extension_get(sf_host *host, size_t index, sf_extension_info *out);
/* Resolve the extension's CLI on PATH (never spawns). node runtimes report
 * SF_LOAD_NOT_APPLICABLE: the D host does not embed a JavaScript engine. */
SF_API int sf_extension_load(sf_host *host, size_t index, sf_load_info *out);
/* Caller-owned JSON; release with sf_free. NULL on error. */
SF_API char *sf_extension_to_json(sf_host *host, size_t index);

SF_API const char *sf_last_error(sf_host *host);
SF_API void sf_free(void *ptr);

#ifdef __cplusplus
}
#endif

#endif /* SHELL_FRAMEWORK_H */
