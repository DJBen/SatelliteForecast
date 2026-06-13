// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QSMag",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "QSMag",
            targets: ["QSMag"])
    ],
    dependencies: [
        // No external dependencies for this module based on Podfile
    ],
    targets: [
        .target(
            name: "QSMag",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "QSMagTests",
            dependencies: ["QSMag"],
            path: "Tests"
        )
    ]
)
