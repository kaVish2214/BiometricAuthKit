//
//  AuthPolicy.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation
import LocalAuthentication


/// The policy that determines what authentication methods are acceptable.
///
/// Use this enumeration to specify whether biometric-only authentication is required
/// or whether the device passcode may also be used as a fallback.
///
/// ```swift
/// let policy: BiometricAuthenticationPolicy = .ownerAuthenticationWithBiometrics
/// ```
public enum BiometricAuthenticationPolicy: Sendable {

    /// Authenticate using biometrics only (Face ID or Touch ID).
    ///
    /// If biometry is unavailable or the user fails authentication, no passcode fallback is offered.
    case ownerAuthenticationWithBiometrics

    /// Authenticate using biometrics with a device passcode fallback.
    ///
    /// If biometry fails or is unavailable, the user can enter their device passcode instead.
    case ownerAuthentication
}

// MARK: - LAPolicy Conversion

/// Maps each ``BiometricAuthenticationPolicy`` case to its corresponding `LAPolicy` value.
extension BiometricAuthenticationPolicy {

    /// The LocalAuthentication framework policy equivalent of this authentication policy.
    public var contextPolicy: LAPolicy {
        switch self {
        case .ownerAuthenticationWithBiometrics:
            return .deviceOwnerAuthenticationWithBiometrics
        case .ownerAuthentication:
            return .deviceOwnerAuthentication
        }
    }
}
