// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenubKit",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "MenubKit", targets: ["MenubKit"])
    ],
    targets: [
        .target(name: "MenubKit"),
        .testTarget(name: "MenubKitTests", dependencies: ["MenubKit"])
    ]
)
