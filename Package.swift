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
    .package(url: "https://github.com/emlynmac/udpconnection", from: .init(2, 0, 0)),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: .init(1, 0, 0)),
  ],
  targets: [
    .target(
      name: "JamulusProtocol",
      dependencies: [
        .product(name: "UdpConnection", package: "udpconnection"),
        .product(name: "Dependencies", package: "swift-dependencies")
      ]),
    .testTarget(
      name: "JamulusProtocolTests",
      dependencies: ["JamulusProtocol"]),
  ]
)
