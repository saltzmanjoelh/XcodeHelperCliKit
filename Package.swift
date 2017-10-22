// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeHelperCliKit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "XcodeHelperCliKit",
            targets: ["XcodeHelperCliKit"]),
        .executable(
            name: "xchelper",
            targets: ["xchelper"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/saltzmanjoelh/XcodeHelperKit.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "XcodeHelperCliKit",
            dependencies: ["XcodeHelperKit"]),
        .target(
            name: "xchelper",
            dependencies: ["XcodeHelperCliKit"]),
        .testTarget(
            name: "XcodeHelperCliKitTests",
            dependencies: ["XcodeHelperCliKit", "XcodeHelperKit"]),
    ]
)
