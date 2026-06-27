// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//  BiometricAuthKit
//
//  Copyright (c) 2026 kaVi Gevariya (@kaVish2214). All rights reserved.
//
//  SPDX-License-Identifier: MPL-2.0
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import PackageDescription

/// swiftSettings
let swiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=100",
        "-Xfrontend", "-warn-long-expression-type-checking=100"
    ])
]

/// Package
let package = Package(
    name: "BiometricAuthKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "BiometricAuth",
            targets: ["BiometricAuth"]
        ),
        .library(
            name: "BiometricAuthInterface",
            targets: ["BiometricAuthInterface"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kaVish2214/UtilityKit", .upToNextMajor(from: "0.1.0"))
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
              "BiometricAuthInterface",
              .product(name: "SwiftConcurrency", package: "UtilityKit")
            ],
            path: "Sources/BiometricAuth",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BiometricAuthKitTests",
            dependencies: ["BiometricAuthInterface","BiometricAuth"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
