//
//  BiometricAuthentication.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation



/// The main interface for performing biometric authentication on a device.
///
/// Conforming types coordinate the full authentication lifecycle — checking availability,
/// triggering the system prompt, delivering results through a ``BiometricAuthenticationDelegator``,
/// and managing reuse timestamps.
///
/// Configuration is provided through a ``BiometricAuthenticationRequestor``, which controls
/// the authentication reason, policy, fallback title, and reuse duration.
///
/// ```swift
/// let auth: BiometricAuthentication = SomeBiometricAuth(
///     requestor: myRequestor,
///     delegator: myDelegate
/// )
///
/// if auth.isAuthenticationSupported && auth.isAuthenticationPermitted {
///     auth.authenticate(Date())
/// }
/// ```
public protocol BiometricAuthentication: Sendable {

    // MARK: - Initialization

    /// Creates a new instance configured with the given requestor and delegator.
    ///
    /// - Parameters:
    ///   - requestor: Provides authentication configuration such as reason, policy, and reuse duration.
    ///   - delegator: Receives success or failure callbacks after authentication completes.
    init(requestor: any BiometricAuthenticationRequestor, delegator: any BiometricAuthenticationDelegator)

    // MARK: - State

    /// The type of biometric authentication available on the current device.
    var availableAuthenticationType: BiometricAuthenticationType { get }

    /// A Boolean value indicating whether an authentication request is currently in progress.
    var isAuthRequestInProcess: Bool { get }

    /// A Boolean value indicating whether the user has granted permission to use biometric authentication.
    var isAuthenticationPermitted: Bool { get }

    /// A Boolean value indicating whether the device supports biometric authentication.
    var isAuthenticationSupported: Bool { get }

    /// The date and time of the most recent authentication request, or `nil` if no request has been made.
    var previousAuthenticationRequestTime: Date? { get }

    /// A Boolean value indicating whether Face ID is the available biometric method.
    var isFacialBiometricAuthenticationAvailable: Bool { get }

    // MARK: - Actions

    /// Initiates a biometric authentication attempt.
    ///
    /// Results are delivered asynchronously through the ``BiometricAuthenticationDelegator``.
    ///
    /// - Parameter requestTime: The timestamp to record for this authentication request.
    func authenticate(_ requestTime: Date)

    /// Cancels any in-progress authentication request.
    func cancelAuthentication()

    /// Invalidates the stored timestamp of the most recent successful authentication.
    ///
    /// After calling this method, the next call to ``authenticate(_:)`` will require
    /// fresh biometric verification regardless of the requestor's reuse duration.
    func invalidateRecentBiometricAuthenticationStamp()
}
