#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GSCEFBrowserHostView;

/// Delegate mirroring the subset of browser state GoldSun's tab sessions track.
@protocol GSCEFBrowserHostViewDelegate <NSObject>
@optional
- (void)cefBrowserHostView:(GSCEFBrowserHostView *)view didUpdateTitle:(NSString *)title;
- (void)cefBrowserHostView:(GSCEFBrowserHostView *)view didUpdatePageURL:(NSURL *)url;
- (void)cefBrowserHostView:(GSCEFBrowserHostView *)view
    didUpdateLoadingState:(BOOL)isLoading
                canGoBack:(BOOL)canGoBack
             canGoForward:(BOOL)canGoForward;

/// Overall page load progress in the range 0.0–1.0.
- (void)cefBrowserHostView:(GSCEFBrowserHostView *)view didUpdateLoadingProgress:(double)progress;

/// A page requested a popup/new window (window.open, target=_blank). The
/// popup itself is suppressed; the host should open |url| in a GoldSun tab.
- (void)cefBrowserHostView:(GSCEFBrowserHostView *)view didRequestPopupWithURL:(NSURL *)url;

/// Page content (for example a video player) toggled HTML fullscreen. With
/// the Alloy runtime CEF only resizes the content; the host is responsible
/// for the native window fullscreen transition.
- (void)cefBrowserHostView:(GSCEFBrowserHostView *)view didChangeContentFullscreen:(BOOL)fullscreen;
@end

/// Owns the CEF process-wide lifecycle for the browser process.
/// All methods must be called on the main thread.
@interface GSCEFRuntime : NSObject

/// True when the bridge was compiled against CEF and the Chromium Embedded
/// Framework is present in the app bundle. Cheap; does not initialize CEF.
@property (class, readonly) BOOL isAvailable;

/// True after an initialization attempt failed; callers should fall back to WebKit.
@property (class, readonly) BOOL initializationFailed;

/// Loads the CEF framework and starts the browser process machinery once.
/// Returns YES if CEF is running (idempotent).
+ (BOOL)initializeIfNeeded;

/// Human-readable runtime description for logging/UI, or nil when unavailable.
@property (class, readonly, nullable) NSString *runtimeDescription;

@end

/// Hosts a single CEF browser as a child of this view.
@interface GSCEFBrowserHostView : NSView

@property (nonatomic, weak, nullable) id<GSCEFBrowserHostViewDelegate> delegate;

/// The URL to load once the browser is created, or immediately if it already is.
- (void)loadURL:(NSURL *)url;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stopLoading;

/// Asks the page to leave HTML fullscreen (used when the user exits native
/// fullscreen directly so the page's fullscreen state stays in sync).
- (void)exitContentFullscreen;

/// Closes the hosted browser. Call when the owning tab is torn down.
- (void)tearDown;

@end

NS_ASSUME_NONNULL_END
