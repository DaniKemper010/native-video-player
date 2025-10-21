// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "better_native_video_player",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(
            name: "better-native-video-player",
            targets: ["better_native_video_player"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "better_native_video_player",
            dependencies: [],
            resources: [
                .process("Resources")
            ],
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)

