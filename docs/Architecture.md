# GoldSun Architecture

## Goals

GoldSun should feel like a native Mac browser before it feels like a port. The Swift layer owns windows, commands, settings, toolbar state, tabs, and user-facing browser workflows. The browser engine sits behind a narrow adapter boundary.

## Targets

- `GoldSunCore`: pure Swift library for durable browser concepts, URL resolution, and engine metadata.
- `GoldSun`: macOS executable for SwiftUI/AppKit UI, tab sessions, and engine hosting.

## Runtime boundaries

- SwiftUI owns scene state, command routing, preferences, tab selection, and layout.
- AppKit bridges own imperative view hosting for embedded browser views.
- The current `WebKitBrowserView` keeps the scaffold runnable while Chromium is integrated.
- The future Chromium adapter should land under `Sources/GoldSun/Services/Chromium` and keep CEF/Chromium types out of views.

## First product surfaces

- Main `WindowGroup` browser window
- Native top tab bar for tab selection
- Compact browser toolbar with navigation and address entry
- Settings scene for homepage/search/engine, extension, and privacy preferences
- Menu commands for common browser actions

## Extension and ad blocking surfaces

- Chrome Web Store compatibility is modeled as a Chromium-only feature. The WebKit development shim is only a temporary browsing surface and should not pretend to run Chrome extensions.
- Extension settings live in the native Settings scene and persist through `@AppStorage`.
- Built-in ad blocking is independent from extension support, so users can keep native blocking on even when no ad-blocking extension is installed.
- The Chromium adapter should compile GoldSun's native ad-block preferences into network/content rules before page load, then let extension-provided `declarativeNetRequest` rules run through the extension subsystem.
