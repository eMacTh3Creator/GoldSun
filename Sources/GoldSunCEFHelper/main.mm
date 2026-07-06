// CEF helper process entry point. This binary is bundled five times inside
// GoldSun.app/Contents/Frameworks as "GoldSun Helper[ (Alerts|GPU|Plugin|
// Renderer)].app" and runs Chromium's secondary processes.

#if __has_include("include/cef_version.h")
#define GOLDSUN_HAS_CEF 1
#endif

#if GOLDSUN_HAS_CEF

#include <dlfcn.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>

#include "include/capi/cef_app_capi.h"

namespace {

// The helper lives at <App>.app/Contents/Frameworks/<Helper>.app/Contents/
// MacOS/<binary>; the CEF framework sits three directories up, matching the
// layout CEF's own library loader expects.
std::string FrameworkBinaryPath() {
    uint32_t size = 0;
    _NSGetExecutablePath(nullptr, &size);
    std::string buffer(size, '\0');
    if (_NSGetExecutablePath(buffer.data(), &size) != 0) {
        return {};
    }

    char resolved[PATH_MAX];
    if (!realpath(buffer.c_str(), resolved)) {
        return {};
    }

    std::string path(resolved);
    for (int i = 0; i < 4; i++) {  // strip binary name + Contents/MacOS + helper bundle
        size_t slash = path.rfind('/');
        if (slash == std::string::npos) {
            return {};
        }
        path.resize(slash);
    }

    return path + "/Chromium Embedded Framework.framework/Chromium Embedded Framework";
}

}  // namespace

int main(int argc, char* argv[]) {
    std::string framework = FrameworkBinaryPath();
    void* library = dlopen(framework.c_str(), RTLD_LAZY | RTLD_LOCAL);
    if (!library) {
        fprintf(stderr, "GoldSunCEFHelper: dlopen failed: %s\n", dlerror());
        return 1;
    }

    auto executeProcess =
        reinterpret_cast<decltype(&cef_execute_process)>(dlsym(library, "cef_execute_process"));
    if (!executeProcess) {
        fprintf(stderr, "GoldSunCEFHelper: missing cef_execute_process symbol\n");
        return 1;
    }

    cef_main_args_t args = {argc, argv};
    return executeProcess(&args, nullptr, nullptr);
}

#else  // !GOLDSUN_HAS_CEF

#include <stdio.h>

int main(int argc, char* argv[]) {
    fprintf(stderr, "GoldSunCEFHelper was built without CEF support.\n");
    return 1;
}

#endif  // GOLDSUN_HAS_CEF
