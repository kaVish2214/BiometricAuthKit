// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BiometricAuthKit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "BiometricAuthKit",
            targets: ["BiometricAuth", "BiometricAuthInterface"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BiometricAuthInterface",
            path: "Sources/BiometricAuthInterface"
        ),
        .target(
            name: "BiometricAuth",
            dependencies: [
              "BiometricAuthInterface"
            ],
            path: "Sources/BiometricAuth"
        ),
        .testTarget(
            name: "BiometricAuthKitTests",
            dependencies: ["BiometricAuthInterface","BiometricAuth"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
