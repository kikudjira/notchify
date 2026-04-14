// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Notchify",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Notchify",
            path: "Sources/Notchify",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "notchify-cli",
            path: "Sources/notchify-cli"
        )
    ]
)
