// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "optune",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "OptuneCore", targets: ["OptuneCore"]),
        .executable(name: "optune", targets: ["OptuneCLI"]),
        .executable(name: "OptuneApp", targets: ["OptuneApp"]),
        .executable(name: "OptuneShowcase", targets: ["OptuneShowcase"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "OptuneCore",
            path: "Sources/OptuneCore"
        ),
        .executableTarget(
            name: "OptuneCLI",
            dependencies: [
                "OptuneCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/OptuneCLI"
        ),
        .executableTarget(
            name: "OptuneApp",
            dependencies: ["OptuneCore"],
            path: "Sources/OptuneApp"
        ),
        .executableTarget(
            name: "OptuneShowcase",
            dependencies: ["OptuneCore"],
            path: "Sources/OptuneShowcase"
        ),
        .testTarget(
            name: "OptuneCoreTests",
            dependencies: ["OptuneCore"],
            path: "Tests/OptuneCoreTests"
        ),
    ]
)
