// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AuthFlow",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
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
    ],
    targets: [
        .target(
            name: "AuthRepositoryProtocol"
        ),
        .target(
            name: "AuthRepository",
            dependencies: ["AuthRepositoryProtocol"]
        ),
        .testTarget(
            name: "AuthRepositoryProtocolTests",
            dependencies: ["AuthRepositoryProtocol"]
        ),
        .testTarget(
            name: "AuthRepositoryTests",
            dependencies: ["AuthRepository"]
        ),
    ]
)
