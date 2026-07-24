// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AuthFlow",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AuthRepository",
            targets: ["AuthRepository"]
        ),
        .library(
            name: "AuthRepositoryProtocol",
            targets: ["AuthRepositoryProtocol"]
        ),
        .library(
            name: "AuthFlowProtocol",
            targets: ["AuthFlowProtocol"]
        ),
        .library(
            name: "AuthFlowUI",
            targets: ["AuthFlowUI"]
        ),
        .library(
            name: "AuthFlowRoutes",
            targets: ["AuthFlowRoutes"]
        ),
    ],
    dependencies: [
        .package(path: "../VaultRepository"),
        .package(path: "../SecureCrypto"),
        .package(path: "../VaultSession"),
        .package(path: "../Navigation"),
    ],
    targets: [
        .target(
            name: "AuthRepositoryProtocol"
        ),
        .target(
            name: "AuthRepository",
            dependencies: [
                "AuthRepositoryProtocol",
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
            ]
        ),
        .target(
            name: "AuthFlowProtocol",
            dependencies: [
                "AuthRepositoryProtocol",
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "VaultSessionProtocol", package: "VaultSession"),
            ]
        ),
        .target(
            name: "AuthFlowRoutes",
            dependencies: [
                .product(name: "NavigationProtocol", package: "Navigation"),
            ]
        ),
        .target(
            name: "AuthFlowUI",
            dependencies: [
                "AuthFlowProtocol",
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "AuthRepositoryProtocolTests",
            dependencies: ["AuthRepositoryProtocol"]
        ),
        .testTarget(
            name: "AuthRepositoryTests",
            dependencies: ["AuthRepository"]
        ),
        .testTarget(
            name: "AuthFlowProtocolTests",
            dependencies: ["AuthFlowProtocol"]
        ),
        .testTarget(
            name: "AuthFlowRoutesTests",
            dependencies: ["AuthFlowRoutes"]
        ),
        .testTarget(
            name: "AuthFlowUITests",
            dependencies: ["AuthFlowUI"]
        ),
    ]
)
