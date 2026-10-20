// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "ChatBotKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ChatBotKit", targets: ["ChatBotKit"]),
    ],
    targets: [
        .target(name: "ChatBotKit"),
        .testTarget(name: "ChatBotKitTests", dependencies: ["ChatBotKit"]),
    ],
    swiftLanguageModes: [.v6]
)
