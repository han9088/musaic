// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "apple_music_kit_ios",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "apple-music-kit-ios", targets: ["apple_music_kit_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "apple_music_kit_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
