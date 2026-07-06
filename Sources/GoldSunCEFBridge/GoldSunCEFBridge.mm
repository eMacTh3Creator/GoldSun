#import "GoldSunCEFBridge.h"

// Compiles the real Chromium integration only when the pinned CEF
// distribution is present (script/fetch_cef.sh); otherwise a stub keeps the
// build green and GoldSun stays on the WebKit fallback.
#if __has_include("include/cef_version.h")
#define GOLDSUN_HAS_CEF 1
#endif

#if GOLDSUN_HAS_CEF

#include <atomic>
#include <cstring>
#include <string>

#include <crt_externs.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <unistd.h>

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_browser_capi.h"
#include "include/capi/cef_browser_process_handler_capi.h"
#include "include/capi/cef_client_capi.h"
#include "include/capi/cef_command_line_capi.h"
#include "include/capi/cef_display_handler_capi.h"
#include "include/capi/cef_frame_capi.h"
#include "include/capi/cef_load_handler_capi.h"
#include "include/cef_api_hash.h"
#include "include/cef_application_mac.h"
#include "include/cef_version.h"

// The framework is loaded with dlopen at runtime (the CEF-supported dynamic
// loading model for macOS), so every libcef entry point used by the bridge is
// resolved through dlsym rather than linked.
namespace {

decltype(&cef_api_hash) g_cef_api_hash = nullptr;
decltype(&cef_initialize) g_cef_initialize = nullptr;
decltype(&cef_shutdown) g_cef_shutdown = nullptr;
decltype(&cef_do_message_loop_work) g_cef_do_message_loop_work = nullptr;
decltype(&cef_browser_host_create_browser_sync) g_cef_browser_host_create_browser_sync = nullptr;
decltype(&cef_string_utf8_to_utf16) g_cef_string_utf8_to_utf16 = nullptr;
decltype(&cef_string_utf16_clear) g_cef_string_utf16_clear = nullptr;

BOOL g_cef_initialized = NO;
BOOL g_cef_init_failed = NO;
NSTimer *g_pump_timer = nil;
NSHashTable<GSCEFBrowserHostView *> *g_live_views = nil;

// External message pump (CEF's recommended integration for apps with an
// existing run loop). Chromium requests pumping via
// on_schedule_message_pump_work; a low-frequency timer acts as a safety net.
// A naive fixed-rate timer alone starves Chromium's scheduler and can wedge
// startup navigations.
void GSPumpWork(void) {
    static BOOL pumping = NO;  // main thread only; cef_do_message_loop_work must not re-enter
    if (pumping || !g_cef_initialized) {
        return;
    }

    pumping = YES;
    g_cef_do_message_loop_work();
    pumping = NO;
}

void GSSchedulePumpWork(int64_t delayMS) {
    if (delayMS <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            GSPumpWork();
        });
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayMS * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        GSPumpWork();
    });
}

struct GSBrowserProcessHandler {
    cef_browser_process_handler_t cef{};
    std::atomic<int> refct{1};
};

struct GSApp {
    cef_app_t cef{};
    std::atomic<int> refct{1};
    GSBrowserProcessHandler *browserProcessHandler = nullptr;
};

void CEF_CALLBACK GSOnScheduleMessagePumpWork(cef_browser_process_handler_t *self,
                                              int64_t delay_ms) {
    // Called from any thread.
    GSSchedulePumpWork(delay_ms);
}

NSString *GSCEFFrameworkBinaryPath(void) {
    NSString *override = NSProcessInfo.processInfo.environment[@"GOLDSUN_CEF_FRAMEWORK"];
    if (override.length > 0) {
        return override;
    }

    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath;
    return [frameworks stringByAppendingPathComponent:
        @"Chromium Embedded Framework.framework/Chromium Embedded Framework"];
}

// Fills |out| with a copy of |string|; release with g_cef_string_utf16_clear.
void GSFillCefString(cef_string_t *out, NSString *string) {
    const char *utf8 = string.UTF8String ?: "";
    g_cef_string_utf8_to_utf16(utf8, strlen(utf8), out);
}

NSString *GSStringFromCefString(const cef_string_t *string) {
    if (!string || !string->str || string->length == 0) {
        return @"";
    }

    return [[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(string->str)
                                         length:string->length];
}

// Manual CEF C API reference counting. Each wrapper embeds its CEF struct as
// the first member so pointers cast both ways.
template <typename Wrapper>
void GSAddRef(cef_base_ref_counted_t *base) {
    reinterpret_cast<Wrapper *>(base)->refct.fetch_add(1, std::memory_order_relaxed);
}

template <typename Wrapper>
int GSRelease(cef_base_ref_counted_t *base) {
    auto *wrapper = reinterpret_cast<Wrapper *>(base);
    if (wrapper->refct.fetch_sub(1, std::memory_order_acq_rel) == 1) {
        delete wrapper;
        return 1;
    }
    return 0;
}

template <typename Wrapper>
int GSHasOneRef(cef_base_ref_counted_t *base) {
    return reinterpret_cast<Wrapper *>(base)->refct.load(std::memory_order_acquire) == 1;
}

template <typename Wrapper>
int GSHasAtLeastOneRef(cef_base_ref_counted_t *base) {
    return reinterpret_cast<Wrapper *>(base)->refct.load(std::memory_order_acquire) >= 1;
}

template <typename Wrapper, typename CefStruct>
void GSInitBase(CefStruct *cefStruct) {
    cefStruct->base.size = sizeof(CefStruct);
    cefStruct->base.add_ref = GSAddRef<Wrapper>;
    cefStruct->base.release = GSRelease<Wrapper>;
    cefStruct->base.has_one_ref = GSHasOneRef<Wrapper>;
    cefStruct->base.has_at_least_one_ref = GSHasAtLeastOneRef<Wrapper>;
}

}  // namespace

// Weakly forwards CEF callbacks to the host view without keeping it alive.
@interface GSCEFViewProxy : NSObject
@property (nonatomic, weak) GSCEFBrowserHostView *view;
@end

@implementation GSCEFViewProxy
@end

namespace {

struct GSDisplayHandler {
    cef_display_handler_t cef{};
    std::atomic<int> refct{1};
    void *proxyRetained = nullptr;

    ~GSDisplayHandler() {
        if (proxyRetained) {
            CFBridgingRelease(proxyRetained);
        }
    }
};

struct GSLoadHandler {
    cef_load_handler_t cef{};
    std::atomic<int> refct{1};
    void *proxyRetained = nullptr;

    ~GSLoadHandler() {
        if (proxyRetained) {
            CFBridgingRelease(proxyRetained);
        }
    }
};

struct GSClient {
    cef_client_t cef{};
    std::atomic<int> refct{1};
    GSDisplayHandler *display = nullptr;
    GSLoadHandler *load = nullptr;

    ~GSClient() {
        if (display) {
            display->cef.base.release(&display->cef.base);
        }
        if (load) {
            load->cef.base.release(&load->cef.base);
        }
    }
};

GSCEFViewProxy *GSProxyFor(void *proxyRetained) {
    return (__bridge GSCEFViewProxy *)proxyRetained;
}

// Ref-counted struct arguments passed into C API callbacks carry a reference
// the callee owns; release them before returning.
void GSReleaseArg(cef_base_ref_counted_t *base) {
    if (base) {
        base->release(base);
    }
}

void CEF_CALLBACK GSOnTitleChange(cef_display_handler_t *self,
                                  cef_browser_t *browser,
                                  const cef_string_t *title) {
    auto *handler = reinterpret_cast<GSDisplayHandler *>(self);
    NSString *value = GSStringFromCefString(title);
    GSCEFBrowserHostView *view = GSProxyFor(handler->proxyRetained).view;
    [view.delegate cefBrowserHostView:view didUpdateTitle:value];
    GSReleaseArg(&browser->base);
}

void CEF_CALLBACK GSOnAddressChange(cef_display_handler_t *self,
                                    cef_browser_t *browser,
                                    cef_frame_t *frame,
                                    const cef_string_t *url) {
    auto *handler = reinterpret_cast<GSDisplayHandler *>(self);
    int isMain = frame ? frame->is_main(frame) : 0;
    NSURL *value = [NSURL URLWithString:GSStringFromCefString(url)];
    if (isMain && value) {
        GSCEFBrowserHostView *view = GSProxyFor(handler->proxyRetained).view;
        [view.delegate cefBrowserHostView:view didUpdatePageURL:value];
    }
    GSReleaseArg(frame ? &frame->base : nullptr);
    GSReleaseArg(&browser->base);
}

void CEF_CALLBACK GSOnLoadingStateChange(cef_load_handler_t *self,
                                         cef_browser_t *browser,
                                         int isLoading,
                                         int canGoBack,
                                         int canGoForward) {
    auto *handler = reinterpret_cast<GSLoadHandler *>(self);
    GSCEFBrowserHostView *view = GSProxyFor(handler->proxyRetained).view;
    [view.delegate cefBrowserHostView:view
                didUpdateLoadingState:isLoading != 0
                            canGoBack:canGoBack != 0
                         canGoForward:canGoForward != 0];
    GSReleaseArg(&browser->base);
}

void CEF_CALLBACK GSOnBeforeCommandLineProcessing(cef_app_t *self,
                                                  const cef_string_t *process_type,
                                                  cef_command_line_t *command_line) {
    // Browser process only (empty process type).
    if (!process_type || process_type->length == 0) {
        // Chromium normally keeps its cookie-encryption key in the macOS
        // Keychain ("Chromium Safe Storage"). Keychain access is tied to the
        // app's code signature, and GoldSun prereleases are ad-hoc signed, so
        // every build would trigger a Keychain password prompt and block page
        // loads until answered. Use the mock keychain until Developer ID
        // signing is in place, then remove this for real at-rest encryption.
        cef_string_t switchName = {};
        GSFillCefString(&switchName, @"use-mock-keychain");
        command_line->append_switch(command_line, &switchName);
        g_cef_string_utf16_clear(&switchName);
    }

    GSReleaseArg(&command_line->base);
}

cef_browser_process_handler_t *CEF_CALLBACK GSGetBrowserProcessHandler(cef_app_t *self) {
    auto *app = reinterpret_cast<GSApp *>(self);
    app->browserProcessHandler->cef.base.add_ref(&app->browserProcessHandler->cef.base);
    return &app->browserProcessHandler->cef;
}

// Application object passed to cef_initialize; lives for the process.
GSApp *GSMakeApp(void) {
    auto *handler = new GSBrowserProcessHandler();
    GSInitBase<GSBrowserProcessHandler>(&handler->cef);
    handler->cef.on_schedule_message_pump_work = GSOnScheduleMessagePumpWork;

    auto *app = new GSApp();
    GSInitBase<GSApp>(&app->cef);
    app->cef.on_before_command_line_processing = GSOnBeforeCommandLineProcessing;
    app->cef.get_browser_process_handler = GSGetBrowserProcessHandler;
    app->browserProcessHandler = handler;
    return app;
}

cef_display_handler_t *CEF_CALLBACK GSGetDisplayHandler(cef_client_t *self) {
    auto *client = reinterpret_cast<GSClient *>(self);
    client->display->cef.base.add_ref(&client->display->cef.base);
    return &client->display->cef;
}

cef_load_handler_t *CEF_CALLBACK GSGetLoadHandler(cef_client_t *self) {
    auto *client = reinterpret_cast<GSClient *>(self);
    client->load->cef.base.add_ref(&client->load->cef.base);
    return &client->load->cef;
}

// Creates a client (refct 1, ownership passes to CEF at browser creation).
GSClient *GSMakeClient(GSCEFBrowserHostView *view) {
    GSCEFViewProxy *proxy = [GSCEFViewProxy new];
    proxy.view = view;

    auto *display = new GSDisplayHandler();
    GSInitBase<GSDisplayHandler>(&display->cef);
    display->cef.on_title_change = GSOnTitleChange;
    display->cef.on_address_change = GSOnAddressChange;
    display->proxyRetained = (void *)CFBridgingRetain(proxy);

    auto *load = new GSLoadHandler();
    GSInitBase<GSLoadHandler>(&load->cef);
    load->cef.on_loading_state_change = GSOnLoadingStateChange;
    load->proxyRetained = (void *)CFBridgingRetain(proxy);

    auto *client = new GSClient();
    GSInitBase<GSClient>(&client->cef);
    client->cef.get_display_handler = GSGetDisplayHandler;
    client->cef.get_load_handler = GSGetLoadHandler;
    client->display = display;
    client->load = load;
    return client;
}

}  // namespace

// CEF requires NSApp to implement CefAppProtocol so Chromium can track
// re-entrant event dispatch (and it messages these selectors unguarded during
// shutdown). SwiftUI installs its own NSApplication subclass and ignores
// NSPrincipalClass, so the protocol methods are grafted onto that class at
// runtime before CEF initializes.
namespace {

const void *kGSHandlingSendEventKey = &kGSHandlingSendEventKey;
IMP g_original_send_event = nullptr;

BOOL GSAppIsHandlingSendEvent(id self, SEL _cmd) {
    return [objc_getAssociatedObject(self, kGSHandlingSendEventKey) boolValue];
}

void GSAppSetHandlingSendEvent(id self, SEL _cmd, BOOL handling) {
    objc_setAssociatedObject(self, kGSHandlingSendEventKey, @(handling),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void GSAppSendEvent(id self, SEL _cmd, NSEvent *event) {
    BOOL wasHandling = GSAppIsHandlingSendEvent(self, nullptr);
    GSAppSetHandlingSendEvent(self, nullptr, YES);
    reinterpret_cast<void (*)(id, SEL, NSEvent *)>(g_original_send_event)(self, _cmd, event);
    GSAppSetHandlingSendEvent(self, nullptr, wasHandling);
}

void GSInstallCefAppProtocolSupport(void) {
    Class appClass = object_getClass(NSApp);

    if (![NSApp respondsToSelector:@selector(isHandlingSendEvent)]) {
        char getterTypes[8];
        char setterTypes[8];
        snprintf(getterTypes, sizeof(getterTypes), "%s@:", @encode(BOOL));
        snprintf(setterTypes, sizeof(setterTypes), "v@:%s", @encode(BOOL));
        class_addMethod(appClass, @selector(isHandlingSendEvent),
                        reinterpret_cast<IMP>(GSAppIsHandlingSendEvent), getterTypes);
        class_addMethod(appClass, @selector(setHandlingSendEvent:),
                        reinterpret_cast<IMP>(GSAppSetHandlingSendEvent), setterTypes);
    }

    if (Method sendEvent = class_getInstanceMethod(appClass, @selector(sendEvent:))) {
        g_original_send_event = method_getImplementation(sendEvent);
        method_setImplementation(sendEvent, reinterpret_cast<IMP>(GSAppSendEvent));
    }

    if (Protocol *protocol = objc_getProtocol("CefAppProtocol")) {
        class_addProtocol(appClass, protocol);
    }
}

}  // namespace

@interface GSCEFBrowserHostView () {
    cef_browser_t *_browser;
}
@property (nonatomic, strong, nullable) NSURL *pendingURL;
@end

@interface GSCEFRuntime ()
+ (void)shutdownForAppTermination;
@end

@implementation GSCEFRuntime

+ (BOOL)isAvailable {
    static BOOL available;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        available = [NSFileManager.defaultManager fileExistsAtPath:GSCEFFrameworkBinaryPath()];
    });
    return available;
}

+ (BOOL)initializationFailed {
    return g_cef_init_failed;
}

+ (NSString *)runtimeDescription {
    if (!self.isAvailable) {
        return nil;
    }

    return [NSString stringWithFormat:@"CEF %d.%d.%d / Chromium %d.%d.%d.%d",
        CEF_VERSION_MAJOR, CEF_VERSION_MINOR, CEF_VERSION_PATCH,
        CHROME_VERSION_MAJOR, CHROME_VERSION_MINOR, CHROME_VERSION_BUILD, CHROME_VERSION_PATCH];
}

+ (BOOL)initializeIfNeeded {
    NSAssert(NSThread.isMainThread, @"GSCEFRuntime must be used from the main thread");

    if (g_cef_initialized) {
        return YES;
    }
    if (g_cef_init_failed) {
        return NO;
    }
    if (!self.isAvailable) {
        g_cef_init_failed = YES;
        return NO;
    }

    g_cef_init_failed = YES;  // cleared on success below

    NSString *frameworkBinary = GSCEFFrameworkBinaryPath();
    void *library = dlopen(frameworkBinary.fileSystemRepresentation, RTLD_LAZY | RTLD_LOCAL);
    if (!library) {
        NSLog(@"GoldSunCEFBridge: dlopen failed: %s", dlerror());
        return NO;
    }

#define GS_LOAD(fn)                                                        \
    do {                                                                   \
        g_##fn = reinterpret_cast<decltype(&fn)>(dlsym(library, #fn));     \
        if (!g_##fn) {                                                     \
            NSLog(@"GoldSunCEFBridge: missing libcef symbol " #fn);        \
            return NO;                                                     \
        }                                                                  \
    } while (0)

    GS_LOAD(cef_api_hash);
    GS_LOAD(cef_initialize);
    GS_LOAD(cef_shutdown);
    GS_LOAD(cef_do_message_loop_work);
    GS_LOAD(cef_browser_host_create_browser_sync);
    GS_LOAD(cef_string_utf8_to_utf16);
    GS_LOAD(cef_string_utf16_clear);
#undef GS_LOAD

    GSInstallCefAppProtocolSupport();

    const char *runtimeHash = g_cef_api_hash(CEF_API_VERSION, 0);
    if (!runtimeHash || strcmp(runtimeHash, CEF_API_HASH_PLATFORM) != 0) {
        NSLog(@"GoldSunCEFBridge: CEF API hash mismatch; bundled framework does not match "
              @"the headers the bridge was compiled against. Re-run script/fetch_cef.sh "
              @"and rebuild.");
        return NO;
    }

    NSString *profileDirectory = [NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
        stringByAppendingPathComponent:@"GoldSun/CEFProfile"];
    [NSFileManager.defaultManager createDirectoryAtPath:profileDirectory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];

    cef_main_args_t mainArgs = {};
    mainArgs.argc = *_NSGetArgc();
    mainArgs.argv = *_NSGetArgv();

    cef_settings_t settings = {};
    settings.size = sizeof(settings);
    settings.no_sandbox = 1;
    settings.multi_threaded_message_loop = 0;
    settings.external_message_pump = 1;
    settings.log_severity = LOGSEVERITY_WARNING;
    GSFillCefString(&settings.cache_path, profileDirectory);
    GSFillCefString(&settings.root_cache_path, profileDirectory);
    GSFillCefString(&settings.log_file,
                    [profileDirectory stringByAppendingPathComponent:@"cef_debug.log"]);
    GSFillCefString(&settings.framework_dir_path,
                    [frameworkBinary stringByDeletingLastPathComponent]);
    GSFillCefString(&settings.main_bundle_path, NSBundle.mainBundle.bundlePath);

    int initialized = g_cef_initialize(&mainArgs, &settings, &GSMakeApp()->cef, NULL);

    g_cef_string_utf16_clear(&settings.cache_path);
    g_cef_string_utf16_clear(&settings.root_cache_path);
    g_cef_string_utf16_clear(&settings.log_file);
    g_cef_string_utf16_clear(&settings.framework_dir_path);
    g_cef_string_utf16_clear(&settings.main_bundle_path);

    if (!initialized) {
        NSLog(@"GoldSunCEFBridge: cef_initialize failed; falling back to WebKit");
        return NO;
    }

    g_cef_init_failed = NO;
    g_cef_initialized = YES;
    g_live_views = [NSHashTable weakObjectsHashTable];

    // Safety-net pump alongside the on_schedule_message_pump_work requests.
    // Common modes keep pages alive during menu tracking and window resizing.
    g_pump_timer = [NSTimer timerWithTimeInterval:1.0 / 30.0
                                          repeats:YES
                                            block:^(NSTimer *timer) {
        GSPumpWork();
    }];
    [NSRunLoop.mainRunLoop addTimer:g_pump_timer forMode:NSRunLoopCommonModes];

    [NSNotificationCenter.defaultCenter
        addObserverForName:NSApplicationWillTerminateNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *notification) {
        [GSCEFRuntime shutdownForAppTermination];
    }];

    NSLog(@"GoldSunCEFBridge: initialized %@", self.runtimeDescription);
    return YES;
}

+ (void)shutdownForAppTermination {
    if (!g_cef_initialized) {
        return;
    }

    [g_pump_timer invalidate];
    g_pump_timer = nil;

    for (GSCEFBrowserHostView *view in g_live_views.allObjects) {
        [view tearDown];
    }

    // Give Chromium a moment to close browsers and flush the profile before
    // cef_shutdown; skipping this risks losing cookies and session state.
    for (int i = 0; i < 40; i++) {
        g_cef_do_message_loop_work();
        usleep(10000);
    }

    g_cef_initialized = NO;
    g_cef_shutdown();
}

@end

@implementation GSCEFBrowserHostView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.autoresizesSubviews = YES;
    }
    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];

    if (self.window && !_browser) {
        [self createBrowserIfPossible];
    }
}

- (void)createBrowserIfPossible {
    // Creating the browser while the view has no size races Chromium's first
    // paint and can leave a permanently white page; layout retries once the
    // view has real bounds.
    if (_browser || !self.window || NSIsEmptyRect(self.bounds)) {
        return;
    }
    if (![GSCEFRuntime initializeIfNeeded]) {
        return;
    }

    NSURL *initialURL = self.pendingURL ?: [NSURL URLWithString:@"about:blank"];
    self.pendingURL = nil;

    cef_window_info_t windowInfo = {};
    windowInfo.size = sizeof(windowInfo);
    windowInfo.parent_view = (__bridge cef_window_handle_t)self;
    windowInfo.bounds.x = 0;
    windowInfo.bounds.y = 0;
    windowInfo.bounds.width = (int)NSWidth(self.bounds);
    windowInfo.bounds.height = (int)NSHeight(self.bounds);

    cef_browser_settings_t browserSettings = {};
    browserSettings.size = sizeof(browserSettings);

    cef_string_t url = {};
    GSFillCefString(&url, initialURL.absoluteString);

    GSClient *client = GSMakeClient(self);
    _browser = g_cef_browser_host_create_browser_sync(
        &windowInfo, &client->cef, &url, &browserSettings, NULL, NULL);
    g_cef_string_utf16_clear(&url);

    if (_browser) {
        [g_live_views addObject:self];
    } else {
        NSLog(@"GoldSunCEFBridge: browser creation failed");
    }
}

- (void)layout {
    [super layout];

    if (!_browser) {
        [self createBrowserIfPossible];
        return;
    }

    if (NSView *browserView = self.subviews.firstObject) {
        if (!NSEqualRects(browserView.frame, self.bounds)) {
            browserView.frame = self.bounds;
        }
    }
}

- (void)loadURL:(NSURL *)url {
    if (!_browser) {
        self.pendingURL = url;
        [self createBrowserIfPossible];
        return;
    }

    cef_frame_t *frame = _browser->get_main_frame(_browser);
    if (!frame) {
        self.pendingURL = url;
        return;
    }

    cef_string_t address = {};
    GSFillCefString(&address, url.absoluteString);
    frame->load_url(frame, &address);
    g_cef_string_utf16_clear(&address);
    frame->base.release(&frame->base);
}

- (void)goBack {
    if (_browser) {
        _browser->go_back(_browser);
    }
}

- (void)goForward {
    if (_browser) {
        _browser->go_forward(_browser);
    }
}

- (void)reload {
    if (_browser) {
        _browser->reload(_browser);
    }
}

- (void)stopLoading {
    if (_browser) {
        _browser->stop_load(_browser);
    }
}

- (void)tearDown {
    if (!_browser) {
        return;
    }

    cef_browser_host_t *host = _browser->get_host(_browser);
    if (host) {
        host->close_browser(host, 1);
        host->base.release(&host->base);
    }

    _browser->base.release(&_browser->base);
    _browser = NULL;
    [g_live_views removeObject:self];
}

- (void)dealloc {
    [self tearDown];
}

@end

#else  // !GOLDSUN_HAS_CEF

// Stub build: the CEF cache was not present at compile time. The app keeps
// building and always reports the Chromium runtime as unavailable so the
// WebKit fallback is used.

@implementation GSCEFRuntime

+ (BOOL)isAvailable {
    return NO;
}

+ (BOOL)initializationFailed {
    return NO;
}

+ (BOOL)initializeIfNeeded {
    return NO;
}

+ (NSString *)runtimeDescription {
    return nil;
}

@end

@implementation GSCEFBrowserHostView

- (void)loadURL:(NSURL *)url {
}

- (void)goBack {
}

- (void)goForward {
}

- (void)reload {
}

- (void)stopLoading {
}

- (void)tearDown {
}

@end

#endif  // GOLDSUN_HAS_CEF
