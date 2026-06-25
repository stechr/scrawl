// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Scrawl",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Scrawl",
            path: "Sources/Scrawl"
        )
    ]
)
