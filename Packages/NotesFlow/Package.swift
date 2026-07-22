// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NotesFlow",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "NotesFlow",
            targets: ["NotesFlow"]
        ),
    ],
    targets: [
        .target(
            name: "NotesFlow"
        ),
        .testTarget(
            name: "NotesFlowTests",
            dependencies: ["NotesFlow"]
        ),
    ]
)
