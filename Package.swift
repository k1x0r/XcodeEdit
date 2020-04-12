// swift-tools-version:4.0
import PackageDescription

let package = Package(
  name: "XcodeEdit",
  products: [
    .library(name: "XcodeEdit", targets: ["XcodeEdit"]),
  ],
  dependencies: [
    .package(url: "https://git.lan/k2utils.git", .branch("master")),
  ],
  targets: [
    .target(name: "XcodeEdit", dependencies: ["k2Utils"]),
  ],
  swiftLanguageVersions: [4]
)

