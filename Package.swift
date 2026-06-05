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
            url: "https://github.com/ARK-Builders/ARK-iOS/releases/download/v0.1.1/arkdrop_uniffiFFI.xcframework.zip",
            checksum: "d57293d5a38cc6862a5de04b3881a598bc51ca7ea39dd477cebbb69994a966fb"
        ),
    ]
)
