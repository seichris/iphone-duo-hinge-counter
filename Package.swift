// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoldCounterCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "FoldCounterCore", targets: ["FoldCounterCore"])],
    targets: [
        .target(name: "FoldCounterCore"),
        .testTarget(name: "FoldCounterCoreTests", dependencies: ["FoldCounterCore"])
    ]
)
