//
//  AuthDelegator.swift
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


/// A delegate that receives the outcome of a biometric authentication attempt.
///
/// Conform to this protocol to handle success and failure callbacks
/// after the user completes (or fails) biometric authentication.
///
/// ```swift
/// final class MyAuthDelegate: BiometricAuthenticationDelegator {
///     func authenticated() {
///         // Proceed to protected content
///     }
///
///     func authenticationFailed(with error: BiometricAuthenticationError) {
///         print(error.localizedDescription)
///     }
///
///     func authenticationRequestInProcess(didChange from: Bool, to: Bool) {
///         // Show or hide an activity indicator
///     }
/// }
/// ```
public protocol BiometricAuthenticationDelegator: AnyObject, Sendable {

    /// Called when the user has been successfully authenticated via biometrics.
    func authenticated()

    /// Called when biometric authentication fails.
    ///
    /// - Parameter error: The specific reason authentication did not succeed.
    func authenticationFailed(with error: BiometricAuthenticationError)
    
    
    /// Called when the authentication request's in-process state changes.
    ///
    /// Use this to update UI elements such as activity indicators when authentication begins or ends.
    ///
    /// - Parameters:
    ///   - from: The previous in-process state.
    ///   - to: The new in-process state.
    func authenticationRequestInProcess(didChange from: Bool, to: Bool)
}
