// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentFrame",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AgentFrame",
            path: "Sources/AgentFrame"
        )
    ]
)
