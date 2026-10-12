// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS("27.0"), .macOS("26.0")],
    products: [.library(name: "Core", targets: ["Core"])],
    targets: [
        .target(name: "Core", path: "Core", resources: [.process("Resources")]),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests",
            exclude: ["DeviceTests"],
            sources: ["CoreTests"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
