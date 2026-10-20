// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "ChatBotKitSwiftUIChat",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ChatCore", targets: ["ChatCore"]),
        .library(name: "ChatUI", targets: ["ChatUI"]),
        .executable(name: "ChatApp", targets: ["ChatApp"]),
    ],
    dependencies: [
        .package(name: "ChatBotKit", path: "../.."),
    ],
    targets: [
        .target(
            name: "ChatCore",
            dependencies: [
                .product(name: "ChatBotKit", package: "ChatBotKit"),
            ]
        ),
        .target(
            name: "ChatUI",
            dependencies: ["ChatCore"]
        ),
        .executableTarget(
            name: "ChatApp",
            dependencies: ["ChatUI", "ChatCore"]
        ),
        .testTarget(
            name: "ChatCoreTests",
            dependencies: ["ChatCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
