// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "musaic_query_macos",
  platforms: [.macOS("12.0")],
  products: [.library(name: "musaic-query-macos", targets: ["musaic_query_macos"])],
  targets: [
    .target(
      name: "musaic_query_macos",
      linkerSettings: [.linkedFramework("iTunesLibrary")]
    )
  ]
)
