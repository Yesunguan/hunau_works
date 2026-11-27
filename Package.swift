// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassHomework",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "GlassHomeworkCore",
            targets: ["GlassHomeworkCore"]
        ),
        .executable(
            name: "GlassHomework",
            targets: ["GlassHomeworkApp"]
        ),
        .executable(
            name: "GlassHomeworkTestRunner",
            targets: ["GlassHomeworkTestRunner"]
        )
    ],
    targets: [
        .target(
            name: "GlassHomeworkCore",
            path: "Sources/GlassHomeworkCore"
        ),
        .executableTarget(
            name: "GlassHomeworkApp",
            dependencies: ["GlassHomeworkCore"],
            path: "Sources/GlassHomeworkApp",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "GlassHomeworkTestRunner",
            dependencies: ["GlassHomeworkCore"],
            path: "Tests/GlassHomeworkCoreTests"
        )
    ]
)
