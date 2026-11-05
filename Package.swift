// swift-tools-version: 6.2
import PackageDescription

// Swift 6 language mode (strict concurrency) is the default with tools 6.2. No third-party dependency.
let package = Package(
    name: "CommandKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "CommandKit", targets: ["CommandKit"]),
        .library(name: "CommandKitAppKit", targets: ["CommandKitAppKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Overlabing/AppSupportKit", exact: "0.1.2"),
    ],
    targets: [
        .target(
            name: "CommandKit", dependencies: [.product(name: "Localization", package: "AppSupportKit")],
            resources: [.process("Resources")]),
        .testTarget(name: "CommandKitTests", dependencies: ["CommandKit"]),
        // macOS only: the files are wrapped in `#if canImport(AppKit)`, so the iOS build sees an empty module.
        .target(name: "CommandKitAppKit", dependencies: ["CommandKit"]),
        .testTarget(name: "CommandKitAppKitTests", dependencies: ["CommandKitAppKit", "CommandKit"]),
    ]
)
