// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ARKiOS",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ArkDrop",
            targets: ["ArkDrop"]
        ),
    ],
    targets: [
        .target(
            name: "ArkDrop",
            dependencies: ["arkdrop_uniffiFFI"],
            path: "core/Sources/ArkDrop"
        ),
        .binaryTarget(
            name: "arkdrop_uniffiFFI",
            path: "core/Artifacts/arkdrop_uniffiFFI.xcframework"
        ),
    ]
)
