//
//  AuthRequestor.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation


/// Configures how a biometric authentication request is presented and evaluated.
///
/// Conform to this protocol to supply the authentication reason, fallback title,
/// policy, reuse duration, and whether authentication should proceed at all.
///
/// Only ``preferredAuthenticationReason()`` is required — the remaining methods
/// have default implementations provided in the extension.
///
/// ```swift
/// struct MyAuthRequest: BiometricAuthenticationRequestor {
///     func preferredAuthenticationReason() -> String {
///         "Unlock your account"
///     }
/// }
/// ```
public protocol BiometricAuthenticationRequestor: Sendable {

    /// Returns whether biometric authentication should be attempted.
    ///
    /// Return `false` to skip the authentication flow entirely.
    func canPerformAuthentication() -> Bool

    /// The duration, in seconds, for which a previous successful authentication can be reused.
    ///
    /// A value of `0` means the user must authenticate every time.
    func preferredAuthenticationAllowableReuseDuration() -> TimeInterval

    /// The reason displayed to the user explaining why authentication is requested.
    ///
    /// This string appears in the system biometric prompt (e.g. the Face ID or Touch ID dialog).
    func preferredAuthenticationReason() -> String

    /// The title for the fallback button shown when biometric authentication fails.
    ///
    /// For example, `"Enter Password"`. Set to an empty string to hide the fallback button.
    func preferredAuthenticationFallbackTitle() -> String

    /// The authentication policy to use for the request.
    ///
    /// Determines whether only biometrics are accepted or a device passcode fallback is allowed.
    func preferredAuthenticationPolicy() -> BiometricAuthenticationPolicy
}

// MARK: - Default Implementations

extension BiometricAuthenticationRequestor {

    /// Defaults to `true`, allowing authentication to proceed.
    public func canPerformAuthentication() -> Bool {
        return true
    }

    /// Defaults to `0`, requiring fresh authentication every time.
    public func preferredAuthenticationAllowableReuseDuration() -> TimeInterval {
        return 0
    }

    /// Defaults to ``BiometricAuthenticationPolicy/ownerAuthentication``, allowing a passcode fallback.
    public func preferredAuthenticationPolicy() -> BiometricAuthenticationPolicy {
        return .ownerAuthentication
    }

    /// Defaults to `"Please use your passcode."`.
    public func preferredAuthenticationFallbackTitle() -> String {
        return "Please use your passcode."
    }
}
