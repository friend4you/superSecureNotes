// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Navigation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Navigation",
            targets: ["Navigation"]
        ),
        .library(
            name: "NavigationProtocol",
            targets: ["NavigationProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "NavigationProtocol"
        ),
        .target(
            name: "Navigation",
            dependencies: ["NavigationProtocol"]
        ),
        .testTarget(
            name: "NavigationProtocolTests",
            dependencies: ["NavigationProtocol"]
        ),
        .testTarget(
            name: "NavigationTests",
            dependencies: ["Navigation"]
        ),
    ]
)
