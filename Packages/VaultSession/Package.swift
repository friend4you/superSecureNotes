// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VaultSession",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "VaultSession",
            targets: ["VaultSession"]
        ),
        .library(
            name: "VaultSessionProtocol",
            targets: ["VaultSessionProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "VaultSessionProtocol"
        ),
        .target(
            name: "VaultSession",
            dependencies: ["VaultSessionProtocol"]
        ),
        .testTarget(
            name: "VaultSessionProtocolTests",
            dependencies: ["VaultSessionProtocol"]
        ),
        .testTarget(
            name: "VaultSessionTests",
            dependencies: ["VaultSession"]
        ),
    ]
)
