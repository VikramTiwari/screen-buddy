// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScreenBuddy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ScreenBuddy", targets: ["ScreenBuddy"])
    ],
    targets: [
        .executableTarget(
            name: "ScreenBuddy",
            path: "Sources/ScreenBuddy"
        )
    ]
)
