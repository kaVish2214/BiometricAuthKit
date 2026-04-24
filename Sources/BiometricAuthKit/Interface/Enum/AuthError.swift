//
//  AuthError.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation
import LocalAuthentication



/// An error that describes why a biometric authentication attempt did not succeed.
///
/// This type wraps the underlying `LAError` codes from the LocalAuthentication
/// framework into a simplified set of cases. Use the ``init(_:)`` initializer
/// to convert an `LAError` into a `BiometricAuthenticationError`.
///
/// Each case provides a localized description through the `LocalizedError` conformance.
public enum BiometricAuthenticationError: Error {

    /// The user failed to provide valid biometric credentials.
    case failed

    /// The user tapped the Cancel button in the authentication dialog.
    case canceledByUser

    /// The user tapped the fallback button (e.g. "Enter Password") in the authentication dialog.
    case fallback

    /// The system canceled authentication (e.g. another app came to the foreground).
    case canceledBySystem

    /// No device passcode is set. A passcode is required before biometric authentication can be used.
    case passcodeNotSet

    /// Biometric authentication is not available on this device.
    case biometryNotAvailable

    /// No biometric data (fingerprints or face) is enrolled on the device.
    case biometryNotEnrolled

    /// Biometry is locked out due to too many failed attempts. The user must enter their passcode to unlock.
    case biometryLockedout

    /// An unrecognized or unexpected authentication error occurred.
    case other
}


// MARK: - LAError Conversion

extension BiometricAuthenticationError {

    /// Creates a `BiometricAuthenticationError` from an optional `LAError`.
    ///
    /// Maps each `LAError` code to the corresponding `BiometricAuthenticationError` case.
    /// If the error is `nil` or its code is unrecognized, defaults to ``other``.
    ///
    /// - Parameter error: The `LAError` returned by the LocalAuthentication framework, or `nil`.
    public init(_ error: LAError?) {
        guard let error = error else {
            self = .other
            return
        }
        switch Int32(error.errorCode) {
        case kLAErrorAuthenticationFailed:
            self = .failed
        case kLAErrorUserCancel:
            self = .canceledByUser
        case kLAErrorUserFallback:
            self = .fallback
        case kLAErrorSystemCancel:
            self = .canceledBySystem
        case kLAErrorPasscodeNotSet:
            self = .passcodeNotSet
        case kLAErrorBiometryNotAvailable:
            self = .biometryNotAvailable
        case kLAErrorBiometryNotEnrolled:
            self = .biometryNotEnrolled
        case kLAErrorBiometryLockout:
            self = .biometryLockedout
        default:
            self = .other
        }
    }
}


// MARK: - LocalizedError

/// Provides user-facing localized descriptions for each authentication error.
extension BiometricAuthenticationError: LocalizedError {

    /// A localized message describing what error occurred during biometric authentication.
    public var errorDescription: String? {
        switch self {
        case .failed:
            return "Authentication has been failed. Please try again later."
        case .canceledByUser:
            return "Authentication has been canceled by user."
        case .fallback:
            return "User has chosen to fallback to password."
        case .canceledBySystem:
            return "Authentication has been canceled by system."
        case .passcodeNotSet:
            return "Please set device passcode to use Biometric authentication."
        case .biometryNotAvailable:
            return "Biometric authentication is not available for this device."
        case .biometryNotEnrolled:
            return "There are no fingerprints or faces enrolled in the device. Please go to Device Settings -> Touch ID & Passcode and enroll your fingerprints or Settings -> Face ID & Passcode and enroll your face."
        case .biometryLockedout:
            return "Face ID or Touch ID is locked now, because of too many failed attempts. Enter passcode to unlock."
        case .other:
            return "Please try again with your enrolled fingerprint or face."
        }
    }
}

