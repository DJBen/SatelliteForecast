// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AlwaysPopover",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AlwaysPopover",
            targets: ["AlwaysPopover"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "AlwaysPopover",
            dependencies: [],
            path: "Sources"
        )
        // If you have tests, define a test target:
        // .testTarget(
        //     name: "AlwaysPopoverTests",
        //     dependencies: ["AlwaysPopover"],
        //     path: "Tests"
        // )
    ]
)
