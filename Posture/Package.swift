// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Hallning",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Hallning",
            path: "Sources/Hallning",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
