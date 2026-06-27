//
//  AuthType.swift
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

import Foundation


/// Represents the type of biometric authentication available on the current device.
///
/// Use this enumeration to determine which biometric authentication mechanism
/// is supported and whether the user has granted permission to use it.
///
/// ```swift
/// let authType: BiometricAuthenticationType = .faceIdentification(permitted: true)
///
/// switch authType {
/// case .faceIdentification(let permitted):
///     print("Face ID available, permitted: \(permitted)")
/// case .touchIdentification(let permitted):
///     print("Touch ID available, permitted: \(permitted)")
/// case .opticIdentification(let permitted):
///     print("Optic ID available, permitted: \(permitted)")
/// case .none:
///     print("No biometric authentication available")
/// }
/// ```
public enum BiometricAuthenticationType: Hashable, Sendable {

    /// Face ID authentication.
    ///
    /// - Parameter permitted: A Boolean value indicating whether the user has granted permission to use Face ID.
    case faceIdentification(permitted: Bool)

    /// Touch ID authentication.
    ///
    /// - Parameter permitted: A Boolean value indicating whether the user has granted permission to use Touch ID.
    case touchIdentification(permitted: Bool)

    /// Optic ID (iris-based) authentication, available on Apple Vision Pro.
    ///
    /// - Parameter permitted: A Boolean value indicating whether the user has granted permission to use Optic ID.
    case opticIdentification(permitted: Bool)

    /// No biometric authentication is available on the device.
    case none
}
