// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VaultRepository",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "VaultRepository",
            targets: ["VaultRepository"]
        ),
        .library(
            name: "VaultRepositoryProtocol",
            targets: ["VaultRepositoryProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "VaultRepositoryProtocol"
        ),
        .target(
            name: "VaultRepository",
            dependencies: ["VaultRepositoryProtocol"]
        ),
        .testTarget(
            name: "VaultRepositoryProtocolTests",
            dependencies: ["VaultRepositoryProtocol"]
        ),
        .testTarget(
            name: "VaultRepositoryTests",
            dependencies: ["VaultRepository"]
        ),
    ]
)
