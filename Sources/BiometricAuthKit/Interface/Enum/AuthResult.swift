//
//  AuthResult.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
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
