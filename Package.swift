// swift-tools-version: 5.6
import PackageDescription

let package = Package(
  name: "JamulusProtocol",
  platforms: [.iOS(.v13), .macOS(.v10_15)],
  products: [
    .library(
      name: "JamulusProtocol",
      targets: ["JamulusProtocol"]),
  ],
  dependencies: [
    .package(url: "https://github.com/emlynmac/udpconnection", branch: "main")
  ],
  targets: [
    .target(
      name: "JamulusProtocol",
      dependencies: [
        .product(name: "UdpConnection", package: "udpconnection")
      ]),
    .testTarget(
      name: "JamulusProtocolTests",
      dependencies: ["JamulusProtocol"]),
  ]
)
