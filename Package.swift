// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GigiGains",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "GigiGains",
            targets: ["GigiGains"]),
    ],
    dependencies: [
        // No external dependencies - using Apple frameworks only per constitutional requirements
    ],
    targets: [
        .target(
            name: "GigiGains",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GigiGainsTests",
            dependencies: ["GigiGains"]),
        .testTarget(
            name: "GigiGainsIntegrationTests",
            dependencies: ["GigiGains"]),
        .testTarget(
            name: "GigiGainsUITests",
            dependencies: ["GigiGains"]),
        .testTarget(
            name: "GigiGainsPerformanceTests",
            dependencies: ["GigiGains"]),
        .testTarget(
            name: "GigiGainsSnapshotTests",
            dependencies: ["GigiGains"])
    ]
)