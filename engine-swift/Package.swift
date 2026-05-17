// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ManeEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ManeEngine", targets: ["ManeEngine"]),
    ],
    targets: [
        .systemLibrary(
            name: "CManeEngine",
            path: "Sources/CManeEngine"
        ),
        .target(
            name: "ManeEngine",
            dependencies: ["CManeEngine"],
            linkerSettings: [
                .linkedLibrary("mane_engine"),
                .unsafeFlags([
                    "-L../target/release"
                ])
            ]
        ),
        .testTarget(
            name: "ManeEngineTests",
            dependencies: ["ManeEngine"]
        ),
    ]
)
