// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SecureCrypto",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SecureCrypto",
            targets: ["SecureCrypto"]
        ),
    ],
    targets: [
        .target(
            name: "SecureCrypto"
        ),
        .testTarget(
            name: "SecureCryptoTests",
            dependencies: ["SecureCrypto"]
        ),
    ]
)
