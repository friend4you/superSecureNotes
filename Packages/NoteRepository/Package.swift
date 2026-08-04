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
        .package(path: "../Network"),
        .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.11.0"),
    ],
    targets: [
        .target(
            name: "NoteRepositoryProtocol",
            dependencies: [
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ]
        ),
        .target(
            name: "NoteRepository",
            dependencies: [
                "NoteRepositoryProtocol",
                .product(name: "VaultRepository", package: "VaultRepository"),
                .product(name: "VaultRepositoryProtocol", package: "VaultRepository"),
                .product(name: "NetworkProtocol", package: "Network"),
                .product(name: "SecureCrypto", package: "SecureCrypto"),
                .product(name: "SQLCipher", package: "SQLCipher.swift"),
            ]
        ),
        .testTarget(
            name: "NoteRepositoryProtocolTests",
            dependencies: [
                "NoteRepositoryProtocol",
                .product(name: "SecureCrypto", package: "SecureCrypto"),
            ]
        ),
        .testTarget(
            name: "NoteRepositoryTests",
            dependencies: [
                "NoteRepository",
                .product(name: "VaultRepository", package: "VaultRepository"),
            ]
        ),
    ]
)
