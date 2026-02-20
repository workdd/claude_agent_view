// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentDock",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "2.2.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgentDock",
            dependencies: [
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
            ],
            path: "Sources/AgentDock"
        ),
        .testTarget(
            name: "AgentDockTests",
            dependencies: [
                "AgentDock",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/AgentDockTests"
        ),
    ]
)
