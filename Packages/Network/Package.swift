// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Network",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "NetworkProtocol",
            targets: ["NetworkProtocol"]
        ),
        .library(
            name: "NetworkMonitoring",
            targets: ["NetworkMonitoring"]
        ),
    ],
    targets: [
        .target(
            name: "NetworkProtocol"
        ),
        .target(
            name: "NetworkMonitoring",
            dependencies: ["NetworkProtocol"]
        ),
        .testTarget(
            name: "NetworkProtocolTests",
            dependencies: ["NetworkProtocol"]
        ),
        .testTarget(
            name: "NetworkMonitoringTests",
            dependencies: ["NetworkMonitoring"]
        ),
    ]
)
