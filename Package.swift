// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClashBar",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "ClashBar", targets: ["ClashBar"]),
        .executable(name: "ClashBarProxyHelper", targets: ["ClashBarProxyHelper"]),
    ],
    targets: [
        .target(
            name: "ProxyHelperShared",
            path: "Sources/Helper/Shared"),
        .executableTarget(
            name: "ClashBar",
            dependencies: ["ProxyHelperShared"],
            path: "Sources/ClashBar",
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/bin"),
                .copy("Resources/Brand"),
                .copy("Resources/ConfigTemplates/ClashBar.yaml"),
                .copy("Resources/ConfigTemplates/SBar.json"),
                .process("Resources/Localization"),
            ]),
        .executableTarget(
            name: "ClashBarProxyHelper",
            dependencies: ["ProxyHelperShared"],
            path: "Sources/Helper/Daemon"),
    ])
