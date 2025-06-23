// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "ActivityView",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "ActivityView",
            targets: ["ActivityView"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "ActivityView",
            dependencies: [],
            path: "Public" // Sources are in the "Public" directory
        )
    ]
)
