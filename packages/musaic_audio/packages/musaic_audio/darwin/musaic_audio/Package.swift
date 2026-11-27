// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "musaic_audio",
    platforms: [
        .iOS("12.0"),
        .macOS("10.14")
    ],
    products: [
        .library(name: "musaic-audio", targets: ["musaic_audio"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "musaic_audio",
            dependencies: [],
            cSettings: [
                .headerSearchPath("include/musaic_audio")
            ]
        )
    ]
)
