// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "XcodeEdit",
  products: [
    .library(name: "XcodeEdit", targets: ["XcodeEdit"]),
  ],
  dependencies: [
    .package(name: "k2Utils", url: "https://github.com/k1x0r/k2utils.git", .branch("master")),
  ],
  targets: [
    .target(name: "XcodeEdit", dependencies: ["k2Utils"]),
  ]
)

