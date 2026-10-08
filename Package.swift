// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NetworkTrail",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "NetworkTrailSDK", targets: ["NetworkTrailSDK"]),
        .library(name: "NetworkTrailWire", targets: ["NetworkTrailWire"]),
        .library(name: "NetworkTrailDebug", type: .dynamic, targets: ["NetworkTrailDebug"]),
        .executable(name: "NetworkTrailMac", targets: ["NetworkTrailMac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "NetworkTrailWire",
            dependencies: [
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
        .target(
            name: "NetworkTrailSDK",
            dependencies: [
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
        .executableTarget(
            name: "NetworkTrailMac",
            dependencies: [
                "NetworkTrailWire",
                .product(name: "Pulse", package: "Pulse"),
            ],
            path: "Apps/Mac/Sources"
        ),
    ]
)
