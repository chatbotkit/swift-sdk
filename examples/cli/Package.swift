// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "ChatBotKitCLI",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(name: "ChatBotKit", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "ChatBotKitCLI",
            dependencies: [
                .product(name: "ChatBotKit", package: "ChatBotKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
