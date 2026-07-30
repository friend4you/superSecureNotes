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
        .library(
            name: "CredentialStoreProtocol",
            targets: ["CredentialStoreProtocol"]
        ),
        .library(
            name: "CredentialStore",
            targets: ["CredentialStore"]
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
            name: "CredentialStoreProtocol"
        ),
        .target(
            name: "CredentialStore",
            dependencies: ["CredentialStoreProtocol"]
        ),
        .target(
            name: "AuthRepositoryProtocol"
        ),
        .target(
            name: "AuthRepository",
            dependencies: [
                "AuthRepositoryProtocol",
                "CredentialStoreProtocol",
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
            ]
        ),
        .target(
            name: "AuthFlowProtocol",
            dependencies: [
                "AuthFlowRoutes",
                "AuthRepository",
                "AuthRepositoryProtocol",
                "CredentialStoreProtocol",
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "VaultSessionProtocol", package: "VaultSession"),
                .product(name: "NavigationProtocol", package: "Navigation"),
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
                "AuthFlowRoutes",
                "CredentialStoreProtocol",
                .product(name: "Navigation", package: "Navigation"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "CredentialStoreTests",
            dependencies: ["CredentialStore", "CredentialStoreProtocol"]
        ),
        .testTarget(
            name: "AuthRepositoryProtocolTests",
            dependencies: ["AuthRepositoryProtocol"]
        ),
        .testTarget(
            name: "AuthRepositoryTests",
            dependencies: [
                "AuthRepository",
                "CredentialStore",
            ]
        ),
        .testTarget(
            name: "AuthFlowProtocolTests",
            dependencies: [
                "AuthFlowProtocol",
                "AuthFlowRoutes",
                "CredentialStoreProtocol",
                .product(name: "NavigationProtocol", package: "Navigation"),
            ]
        ),
        .testTarget(
            name: "AuthFlowRoutesTests",
            dependencies: ["AuthFlowRoutes"]
        ),
        .testTarget(
            name: "AuthFlowUITests",
            dependencies: [
                "AuthFlowUI",
                "AuthFlowRoutes",
                .product(name: "NavigationProtocol", package: "Navigation"),
            ]
        ),
    ]
)
