// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AnchorKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .executable(name: "anchor", targets: ["AnchorCLI"]),
        .library(name: "AnchorCore", targets: ["AnchorCore"]),
        .library(name: "AnchorDesign", targets: ["AnchorDesign"]),
        .library(name: "AnchorIOSFeatures", targets: ["AnchorIOSFeatures"]),
        .library(name: "AnchorMacFeatures", targets: ["AnchorMacFeatures"]),
        .library(name: "AnchorTransport", targets: ["AnchorTransport"]),
    ],
    targets: [
        .executableTarget(
            name: "AnchorCLI",
            dependencies: ["AnchorCore"]
        ),
        .target(
            name: "AnchorCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "AnchorDesign",
            dependencies: ["AnchorCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "AnchorIOSFeatures",
            dependencies: ["AnchorCore", "AnchorDesign"]
        ),
        .target(
            name: "AnchorMacFeatures",
            dependencies: ["AnchorCore", "AnchorDesign"]
        ),
        .target(
            name: "AnchorTransport",
            dependencies: ["AnchorCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AnchorCoreTests",
            dependencies: ["AnchorCore"]
        ),
        .testTarget(
            name: "AnchorMacFeaturesTests",
            dependencies: ["AnchorCore", "AnchorMacFeatures"]
        ),
        .testTarget(
            name: "AnchorTransportTests",
            dependencies: ["AnchorCore", "AnchorTransport"]
        ),
    ]
)
