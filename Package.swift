// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GoldSun",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GoldSunCore", targets: ["GoldSunCore"]),
        .executable(name: "GoldSun", targets: ["GoldSun"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GoldSunCore",
            path: "Sources/GoldSunCore"
        ),
        .executableTarget(
            name: "GoldSun",
            dependencies: ["GoldSunCore"],
            path: "Sources/GoldSun",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "GoldSunCoreTests",
            dependencies: ["GoldSunCore"],
            path: "Tests/GoldSunCoreTests"
        )
    ]
)
