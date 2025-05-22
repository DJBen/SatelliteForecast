// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SecondaryTabView",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SecondaryTabView",
            targets: ["SecondaryTabView"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "SecondaryTabView",
            dependencies: [],
            path: "Sources"
        )
        // If you have tests, define a test target:
        // .testTarget(
        //     name: "SecondaryTabViewTests",
        //     dependencies: ["SecondaryTabView"],
        //     path: "Tests"
        // )
    ]
)
