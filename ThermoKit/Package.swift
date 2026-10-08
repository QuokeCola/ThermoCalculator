// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThermoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ThermoKit", targets: ["ThermoKit"])
    ],
    targets: [
        .target(
            name: "ThermoKit",
            resources: [.copy("Resources/steam")]
        ),
        .testTarget(
            name: "ThermoKitTests",
            dependencies: ["ThermoKit"]
        ),
    ]
)
