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
