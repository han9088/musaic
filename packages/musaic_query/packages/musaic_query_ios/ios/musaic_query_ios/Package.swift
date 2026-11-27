// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "musaic_query_ios",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "musaic-query-ios", targets: ["musaic_query_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.1.1")
    ],
    targets: [
        .target(
            name: "musaic_query_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
            ]
        )
    ]
)
