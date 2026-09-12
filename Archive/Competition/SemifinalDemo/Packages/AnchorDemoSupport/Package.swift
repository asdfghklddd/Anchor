// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AnchorDemoSupport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "AnchorDemoSupport", targets: ["AnchorDemoSupport"]),
    ],
    dependencies: [
        .package(path: "../../../../../Packages/AnchorKit"),
    ],
    targets: [
        .target(
            name: "AnchorDemoSupport",
            dependencies: [
                .product(name: "AnchorCore", package: "AnchorKit"),
                .product(name: "AnchorDesign", package: "AnchorKit"),
                .product(name: "AnchorIOSFeatures", package: "AnchorKit"),
                .product(name: "AnchorMacFeatures", package: "AnchorKit"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AnchorDemoSupportTests",
            dependencies: [
                .product(name: "AnchorCore", package: "AnchorKit"),
                "AnchorDemoSupport",
            ]
        ),
    ]
)
