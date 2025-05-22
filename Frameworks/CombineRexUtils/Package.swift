// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CombineRexUtils",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CombineRexUtils",
            targets: ["CombineRexUtils"])
    ],
    dependencies: [
        // From Podfile, it depends on CombineRex and SwiftRex, which come from the same package
        .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.12")
    ],
    targets: [
        .target(
            name: "CombineRexUtils",
            dependencies: [
                .product(name: "CombineRex", package: "SwiftRex"),
                .product(name: "SwiftRex", package: "SwiftRex")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CombineRexUtilsTests",
            dependencies: ["CombineRexUtils"],
            path: "Tests"
        )
    ]
)
