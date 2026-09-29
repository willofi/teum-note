// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Teum",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Teum", targets: ["TeumApp"])],
    targets: [
        .target(name: "TeumCore"),
        .executableTarget(name: "TeumApp", dependencies: ["TeumCore"]),
        .testTarget(name: "TeumCoreTests", dependencies: ["TeumCore"])
    ]
)
