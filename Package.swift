// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BeoplayRemote",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "BeoplayRemoteCore",
            targets: ["RemoteCore"]),
        .library(
            name: "Emulator",
            targets: ["Emulator"]),
        .executable(
            name: "beoplay-cli",
            targets: ["RemoteCLI"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "4.0.0"),
        .package(url: "https://github.com/andybest/linenoise-swift", from: "0.0.3"),
        .package(url: "https://github.com/IBM-Swift/Kitura", from: "2.8.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "RemoteCLI",
            dependencies: ["RemoteCore", "Emulator", "LineNoise"]),
        .target(
            name: "Emulator",
            dependencies: ["RemoteCore", "Kitura", "SwiftyJSON"]),
        .target(
            name: "RemoteCore",
            dependencies: ["SwiftyJSON"]),
        .testTarget(
            name: "RemoteCoreTests",
            dependencies: ["RemoteCore"]),
    ]
)
