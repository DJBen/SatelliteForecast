// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SwiftUIVisualEffects",
    platforms: [
        .iOS(.v18)
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
