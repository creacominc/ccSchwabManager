// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ccSchwabManager",
    platforms: [
        .macOS(.v13), // Latest stable macOS version
        .iOS(.v16)    // Latest stable iOS version
    ],
    products: [
        .executable(
            name: "ccSchwabManager",
            targets: ["ccSchwabManager"]
        )
    ],
    dependencies: [
        // Add any external dependencies here, for example:
        // .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "ccSchwabManager",
            dependencies: [
                // List dependencies for this target here
            ],
            path: "ccSchwabManager"
        ),
        .testTarget(
            name: "ccSchwabManagerTests",
            dependencies: ["ccSchwabManager"],
            path: "ccSchwabManagerTests"
        )
    ]
)