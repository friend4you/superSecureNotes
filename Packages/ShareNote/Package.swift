// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ShareNote",
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
    ],
    targets: [
        .target(
            name: "ShareNote",
            dependencies: [
                "ShareNoteRoutes",
                .product(name: "Navigation", package: "Navigation"),
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
            dependencies: ["ShareNote"]
        ),
        .testTarget(
            name: "ShareNoteRoutesTests",
            dependencies: ["ShareNoteRoutes"]
        ),
    ]
)
