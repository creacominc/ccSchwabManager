// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ccSchwabManager",
    platforms: [
        .macOS(.v15), // macOS 15.2 deployment target
        .iOS(.v18)    // iOS 18.2 deployment target
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