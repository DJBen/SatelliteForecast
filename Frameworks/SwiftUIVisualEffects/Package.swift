// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftUIVisualEffects",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftUIVisualEffects",
            targets: ["SwiftUIVisualEffects"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "SwiftUIVisualEffects",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftUIVisualEffectsTests",
            dependencies: ["SwiftUIVisualEffects"],
            path: "Tests"
        )
    ]
)
