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
        .executableTarget(
            name: "TrackerCoreTests",
            dependencies: ["TrackerCore"],
            path: "Tests/TrackerCoreTests"
        ),
    ]
)
