// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NetworkTrail",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NetworkTrailSDK", targets: ["NetworkTrailSDK"]),
        .library(name: "NetworkTrailWire", targets: ["NetworkTrailWire"]),
        .library(name: "NetworkTrailDebug", type: .dynamic, targets: ["NetworkTrailDebug"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "NetworkTrailProtocol",
            dependencies: [
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
        .target(
            name: "NetworkTrailWire",
            dependencies: [
                "NetworkTrailProtocol",
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
        .target(
            name: "NetworkTrailSDK",
            dependencies: [
                "NetworkTrailProtocol",
                .product(name: "Pulse", package: "Pulse"),
                .product(name: "PulseProxy", package: "Pulse"),
            ]
        ),
        .target(
            name: "NetworkTrailDebug",
            dependencies: [
                "NetworkTrailSDK",
            ],
            exclude: [
                "NetworkTrailDebugLoader.m",
                "include",
            ]
        ),
        .testTarget(
            name: "NetworkTrailWireTests",
            dependencies: ["NetworkTrailWire"]
        ),
        .testTarget(
            name: "NetworkTrailProtocolTests",
            dependencies: [
                "NetworkTrailProtocol",
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
    ]
)
