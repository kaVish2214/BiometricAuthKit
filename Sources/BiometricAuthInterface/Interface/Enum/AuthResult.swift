//
//  AuthResult.swift
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


/// The outcome of a biometric authentication attempt.
///
/// Use this enumeration to handle the result of authenticating with Face ID or Touch ID.
///
/// ```swift
/// let result: BiometricAuthenticationResult = ...
///
/// switch result {
/// case .success:
///     print("User authenticated successfully")
/// case .failure(let error):
///     print("Authentication failed: \(error.localizedDescription)")
/// }
/// ```
public enum BiometricAuthenticationResult: Sendable {

    /// The user was authenticated successfully.
    case success

    /// Authentication failed with the associated error describing the reason.
    case failure(BiometricAuthenticationError)
}
