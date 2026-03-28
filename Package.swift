// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "RemindMe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "RemindMe",
            targets: ["RemindMe"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "RemindMe",
            dependencies: [],
            path: "RemindMe"
        ),
        .testTarget(
            name: "RemindMeTests",
            dependencies: ["RemindMe"],
            path: "RemindMeTests"
        ),
    ]
)
