// swift-tools-version: 5.9

import Foundation
import PackageDescription

// The CEF binary distribution is fetched by script/fetch_cef.sh into an
// ignored local cache. The include path is passed unconditionally (clang
// ignores missing -I directories) and the sources decide with __has_include:
// with the cache present the Objective-C++ bridge compiles the real Chromium
// integration; without it (for example on CI) it compiles a stub and GoldSun
// falls back to the WebKit development shim at runtime. Keeping the manifest
// static avoids SwiftPM's manifest-result caching freezing the decision.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let cefCxxSettings: [CXXSetting] = [
    .unsafeFlags(["-I", "\(packageRoot)/ThirdParty/CEFCache/current"])
]

let package = Package(
    name: "GoldSun",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GoldSunCore", targets: ["GoldSunCore"]),
        .executable(name: "GoldSun", targets: ["GoldSun"]),
        .executable(name: "GoldSunCEFHelper", targets: ["GoldSunCEFHelper"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GoldSunCore",
            path: "Sources/GoldSunCore"
        ),
        .target(
            name: "GoldSunCEFBridge",
            path: "Sources/GoldSunCEFBridge",
            publicHeadersPath: "include",
            cxxSettings: cefCxxSettings,
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "GoldSunCEFHelper",
            path: "Sources/GoldSunCEFHelper",
            cxxSettings: cefCxxSettings
        ),
        .executableTarget(
            name: "GoldSun",
            dependencies: ["GoldSunCore", "GoldSunCEFBridge"],
            path: "Sources/GoldSun",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
                .linkedFramework("WebKit"),
                .linkedLibrary("c++")
            ]
        ),
        .testTarget(
            name: "GoldSunCoreTests",
            dependencies: ["GoldSunCore"],
            path: "Tests/GoldSunCoreTests"
        )
    ],
    cxxLanguageStandard: .cxx20
)
