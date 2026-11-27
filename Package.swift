// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "hunau_works",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "HunauWorksCore",
            targets: ["HunauWorksCore"]
        ),
        .executable(
            name: "hunau_works",
            targets: ["HunauWorksApp"]
        ),
        .executable(
            name: "HunauWorksTestRunner",
            targets: ["HunauWorksTestRunner"]
        )
    ],
    targets: [
        .target(
            name: "HunauWorksCore",
            path: "Sources/HunauWorksCore"
        ),
        .executableTarget(
            name: "HunauWorksApp",
            dependencies: ["HunauWorksCore"],
            path: "Sources/HunauWorksApp",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "HunauWorksTestRunner",
            dependencies: ["HunauWorksCore"],
            path: "Tests/HunauWorksCoreTests"
        )
    ]
)
