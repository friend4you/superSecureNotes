// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NoteRepository",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "NoteRepository",
            targets: ["NoteRepository"]
        ),
        .library(
            name: "NoteRepositoryProtocol",
            targets: ["NoteRepositoryProtocol"]
        ),
    ],
    dependencies: [
        .package(path: "../VaultRepository"),
        .package(path: "../SecureCrypto"),
    ],
    targets: [
        .target(
            name: "NoteRepositoryProtocol"
        ),
        .target(
            name: "NoteRepository",
            dependencies: [
                "NoteRepositoryProtocol",
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ]
        ),
        .testTarget(
            name: "NoteRepositoryProtocolTests",
            dependencies: ["NoteRepositoryProtocol"]
        ),
        .testTarget(
            name: "NoteRepositoryTests",
            dependencies: ["NoteRepository"]
        ),
    ]
)
