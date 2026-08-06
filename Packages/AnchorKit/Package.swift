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
        .library(name: "AnchorDemoSupport", targets: ["AnchorDemoSupport"]),
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
            name: "AnchorDemoSupport",
            dependencies: [
                "AnchorCore",
                "AnchorDesign",
                "AnchorIOSFeatures",
                "AnchorMacFeatures",
            ],
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
            name: "AnchorDemoSupportTests",
            dependencies: ["AnchorCore", "AnchorDemoSupport"]
        ),
        .testTarget(
            name: "AnchorTransportTests",
            dependencies: ["AnchorCore", "AnchorTransport"]
        ),
    ]
)
