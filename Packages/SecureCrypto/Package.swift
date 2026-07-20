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
        .library(
            name: "SecureCryptoProtocol",
            targets: ["SecureCryptoProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "SecureCryptoProtocol",
            resources: [
                .process("Mnemonic/Resources"),
            ]
        ),
        .target(
            name: "SecureCrypto",
            dependencies: ["SecureCryptoProtocol"]
        ),
        .testTarget(
            name: "SecureCryptoProtocolTests",
            dependencies: ["SecureCryptoProtocol"]
        ),
        .testTarget(
            name: "SecureCryptoTests",
            dependencies: ["SecureCrypto"]
        ),
    ]
)
