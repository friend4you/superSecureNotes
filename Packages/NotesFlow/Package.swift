// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NotesFlow",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "NotesFlow",
            targets: ["NotesFlow"]
        ),
        .library(
            name: "NotesFlowRoutes",
            targets: ["NotesFlowRoutes"]
        ),
    ],
    dependencies: [
        .package(path: "../Navigation"),
        .package(path: "../AuthFlow"),
        .package(path: "../VaultSession"),
        .package(path: "../ShareNote"),
        .package(path: "../NoteRepository"),
    ],
    targets: [
        .target(
            name: "NotesFlow",
            dependencies: [
                "NotesFlowRoutes",
                .product(name: "Navigation", package: "Navigation"),
                .product(name: "AuthRepositoryProtocol", package: "AuthFlow"),
                .product(name: "AuthFlowRoutes", package: "AuthFlow"),
                .product(name: "VaultSessionProtocol", package: "VaultSession"),
                .product(name: "ShareNoteRoutes", package: "ShareNote"),
                .product(name: "NoteRepositoryProtocol", package: "NoteRepository"),
            ]
        ),
        .target(
            name: "NotesFlowRoutes",
            dependencies: [
                .product(name: "NavigationProtocol", package: "Navigation"),
            ]
        ),
        .testTarget(
            name: "NotesFlowTests",
            dependencies: ["NotesFlow"]
        ),
        .testTarget(
            name: "NotesFlowRoutesTests",
            dependencies: ["NotesFlowRoutes"]
        ),
    ]
)
