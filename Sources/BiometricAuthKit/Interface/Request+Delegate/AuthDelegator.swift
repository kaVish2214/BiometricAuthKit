//
//  AuthDelegator.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation





/// A delegate that receives the outcome of a biometric authentication attempt.
///
/// Conform to this protocol to handle success and failure callbacks
/// after the user completes (or fails) biometric authentication.
///
/// ```swift
/// struct MyAuthDelegate: BiometricAuthenticationDelegator {
///     func authenticated() {
///         // Proceed to protected content
///     }
///
///     func authenticationFailed(with error: BiometricAuthenticationError) {
///         print(error.localizedDescription)
///     }
/// }
/// ```
public protocol BiometricAuthenticationDelegator: Sendable {

    /// Called when the user has been successfully authenticated via biometrics.
    func authenticated()

    /// Called when biometric authentication fails.
    ///
    /// - Parameter error: The specific reason authentication did not succeed.
    func authenticationFailed(with error: BiometricAuthenticationError)
}
