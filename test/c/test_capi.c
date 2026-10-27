/* C ABI smoke test. Usage: test_capi <repo-root> */
#include <stdio.h>
#include <string.h>
#include "shell_framework.h"

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL %s:%d: %s (%s)\n", __FILE__, __LINE__, #c, sf_last_error(h)); return 1; } } while (0)

int main(int argc, char **argv)
{
    sf_host *h = NULL;
    sf_extension_info info;
    sf_load_info load;
    const char *json = "{\"schemaVersion\":1,\"id\":\"example/demo\",\"name\":\"Demo\",\"repository\":\"https://github.com/example/demo\",\"runtime\":\"cli\",\"cli\":{\"binary\":\"sf-demo-not-installed\"}}";
    char *dump;
    if (argc < 2) { fprintf(stderr, "usage: %s <repo-root>\n", argv[0]); return 2; }

    CHECK(strcmp(sf_version(), "0.1.0") == 0);
    h = sf_host_create();
    CHECK(h != NULL);
    CHECK(sf_discover(h, argv[1]) == 1);
    CHECK(sf_extension_count(h) == 1);
    CHECK(sf_extension_get(h, 0, &info) == SF_OK);
    CHECK(strcmp(info.id, "openshellorg/prohelp") == 0);
    CHECK(info.core == 1 && info.source == SF_SOURCE_CORE);
    CHECK(strcmp(info.cli_binary, "prohelp") == 0);
    CHECK(strcmp(info.runtime, "dub") == 0 && strcmp(info.dub_package, "prohelp") == 0);
    CHECK(sf_load_manifest_json(h, json, strlen(json)) == SF_OK);
    CHECK(sf_load_manifest_json(h, json, strlen(json)) == SF_ERROR);
    CHECK(strstr(sf_last_error(h), "already registered") != NULL);
    CHECK(sf_extension_count(h) == 2);
    CHECK(sf_extension_load(h, 0, &load) == SF_OK);
    CHECK(load.state == SF_LOAD_MISSING && strstr(load.reason, "sf-demo-not-installed") != NULL);
    dump = sf_extension_to_json(h, 0);
    CHECK(dump != NULL && strstr(dump, "example/demo") != NULL);
    sf_free(dump);
    sf_host_destroy(h);
    h = NULL;
    printf("C ABI test passed\n");
    return 0;
}
