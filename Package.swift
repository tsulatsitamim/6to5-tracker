// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PresenceTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TrackerCore"),
        .executableTarget(
            name: "TrackerApp",
            dependencies: ["TrackerCore"]
        ),
        .testTarget(
            name: "TrackerCoreTests",
            dependencies: ["TrackerCore"]
        ),
    ]
)
