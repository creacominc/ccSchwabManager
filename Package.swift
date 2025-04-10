// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "ccSchwabManager",
    platforms: [
        .macOS(.v12), // Specify the minimum macOS version or other platforms if needed
        .iOS(.v15)    // Add iOS if applicable
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