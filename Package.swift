// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ccSchwabManager",
    platforms: [
        .macOS(.v14), // Latest supported macOS version in SPM
        .iOS(.v17)    // Latest supported iOS version in SPM
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