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
        .package(path: "../Network"),
        .package(path: "../NoteRepository"),
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
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
            ]
        ),
        .target(
            name: "AuthFlowProtocol",
            dependencies: [
                "AuthFlowRoutes",
                "AuthRepositoryProtocol",
                "CredentialStoreProtocol",
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "VaultSessionProtocol", package: "VaultSession"),
                .product(name: "NavigationProtocol", package: "Navigation"),
                .product(name: "NetworkProtocol", package: "Network"),
                .product(name: "NoteRepositoryProtocol", package: "NoteRepository"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
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
                .product(name: "NetworkProtocol", package: "Network"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
                .product(name: "NoteRepositoryProtocol", package: "NoteRepository"),
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
                "AuthFlowProtocol",
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
                .product(name: "NetworkProtocol", package: "Network"),
                .product(name: "NoteRepositoryProtocol", package: "NoteRepository"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
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
