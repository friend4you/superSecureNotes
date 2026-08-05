// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ShareNote",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ShareNote",
            targets: ["ShareNote"]
        ),
        .library(
            name: "ShareNoteRoutes",
            targets: ["ShareNoteRoutes"]
        ),
    ],
    dependencies: [
        .package(path: "../Navigation"),
        .package(path: "../NoteRepository"),
        .package(path: "../VaultRepository"),
        .package(path: "../VaultSession"),
        .package(path: "../SecureCrypto"),
    ],
    targets: [
        .target(
            name: "ShareNote",
            dependencies: [
                "ShareNoteRoutes",
                .product(name: "Navigation", package: "Navigation"),
                .product(name: "NoteRepositoryProtocol", package: "NoteRepository"),
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "VaultSessionProtocol", package: "VaultSession"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "ShareNoteRoutes",
            dependencies: [
                .product(name: "NavigationProtocol", package: "Navigation"),
            ]
        ),
        .testTarget(
            name: "ShareNoteTests",
            dependencies: [
                "ShareNote",
                .product(name: "NoteRepositoryProtocol", package: "NoteRepository"),
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "VaultSessionProtocol", package: "VaultSession"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ]
        ),
        .testTarget(
            name: "ShareNoteRoutesTests",
            dependencies: ["ShareNoteRoutes"]
        ),
    ]
)
