//
//  BiometricAuthManager.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation
import LocalAuthentication




/// The concrete implementation of ``BiometricAuthentication`` that manages Face ID and Touch ID
/// authentication using the LocalAuthentication framework.
///
/// `BiometricAuthManager` coordinates the full biometric lifecycle:
/// 1. Evaluates device capabilities and user permissions.
/// 2. Presents the system biometric prompt configured by a ``BiometricAuthenticationRequestor``.
/// 3. Delivers results to a ``BiometricAuthenticationDelegator`` on the main queue.
/// 4. Supports authentication reuse within a configurable time window.
///
/// ```swift
/// let manager = BiometricAuthManager(
///     requestor: myRequestor,
///     delegator: myDelegate
/// )
///
/// let authType = manager.availableAuthenticationType
/// if authType != .none {
///     manager.authenticate(Date())
/// }
/// ```
public final class BiometricAuthManager: NSObject, BiometricAuthentication, @unchecked Sendable {

    // MARK: - Properties

    /// The current `LAContext` used for an in-progress authentication, or `nil` when idle.
    private var context: LAContext?

    /// The requestor that provides authentication configuration.
    let requestor: any BiometricAuthenticationRequestor

    /// The delegator that receives authentication outcome callbacks.
    let delegator: any BiometricAuthenticationDelegator

    /// A Boolean value indicating whether an authentication request is currently in progress.
    private(set) public var isAuthRequestInProcess: Bool = false {
        didSet {
            self.handleRequestInProcessChange(from: oldValue, to: isAuthRequestInProcess)
        }
    }

    /// The timestamp of the most recent successful authentication, used for reuse duration checks.
    private(set) var previousAuthenticationTime: Date? = nil

    /// The date and time of the most recent authentication request, or `nil` if no request has been made.
    public var previousAuthenticationRequestTime: Date? {
        return previousAuthenticationTime
    }

    /// A Boolean value indicating whether Face ID is the available biometric method.
    public var isFacialBiometricAuthenticationAvailable: Bool {
        if case .faceIdentification = availableAuthenticationType {
            return true
        }
        return false
    }

    // MARK: - Initialization

    /// Creates a new biometric authentication manager.
    ///
    /// - Parameters:
    ///   - requestor: Provides authentication configuration such as reason, policy, and reuse duration.
    ///   - delegator: Receives success or failure callbacks after authentication completes.
    public required init(requestor: any BiometricAuthenticationRequestor, delegator: any BiometricAuthenticationDelegator) {
        self.requestor = requestor
        self.delegator = delegator
        super.init()
    }
}

// MARK: - BiometricAuthentication Conformance

extension BiometricAuthManager {

    /// The type of biometric authentication available on the current device.
    ///
    /// Evaluates the device's `LAContext` each time it is accessed to determine
    /// whether Face ID, Touch ID, or no biometry is available, along with the
    /// user's permission status.
    public var availableAuthenticationType: BiometricAuthenticationType {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available.
        // If it is disabled to access FaceID, `canEvaluatePolicy()` returns `false` and `LAError.biometryNotAvailable` is assigned to error.
        let isEvaluateSuccess = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        guard error == nil else {
            return .none
        }
        
        let type: BiometricAuthenticationType
        if #available(macOS 10.13.2, *) {
            // On macOS 10.13.2 or later, determine type by `LABiometryType`
            switch context.biometryType {
            case .faceID:
                type = .faceIdentification(permitted: isEvaluateSuccess)
            case .touchID:
                type = .touchIdentification(permitted: isEvaluateSuccess)
            case .none:
                type = .none
            default:
                type = .none
            }
        } else {
            if isEvaluateSuccess {
                type = .touchIdentification(permitted: isEvaluateSuccess)
            } else {
                type = .none
            }
        }
        
        return type
    }
    
    /// A Boolean value indicating whether the user has granted permission to use biometric authentication.
    public var isAuthenticationPermitted: Bool {
        switch availableAuthenticationType {
        case .faceIdentification(let permitted), .touchIdentification(let permitted):
            return permitted
        case .none:
            return false
        }
    }

    /// A Boolean value indicating whether the device supports biometric authentication (Face ID or Touch ID).
    public var isAuthenticationSupported: Bool {
        availableAuthenticationType != .none
    }
    
    /// Initiates a biometric authentication attempt.
    ///
    /// If a previous successful authentication falls within the requestor's
    /// ``BiometricAuthenticationRequestor/preferredAuthenticationAllowableReuseDuration()``,
    /// the delegator is notified of success immediately without prompting the user again.
    ///
    /// Results are delivered asynchronously on the main queue through the ``BiometricAuthenticationDelegator``.
    ///
    /// - Parameter requestTime: The timestamp to record for this authentication request.
    public func authenticate(_ requestTime: Date) {
        guard !isAuthRequestInProcess else { return }
        if let previous = previousAuthenticationTime,
           requestor.preferredAuthenticationAllowableReuseDuration() > 0,
           requestTime.timeIntervalSince(previous) < requestor.preferredAuthenticationAllowableReuseDuration() {
            notifyAuth(true, error: nil)
            return
        }
        isAuthRequestInProcess = true
        validateAuthenticationRequest(requestTime)
    }
    
    /// Initiates a biometric authentication attempt and delivers the result via a completion handler.
    ///
    /// Behaves identically to ``authenticate(_:)`` but additionally calls the completion handler
    /// with a ``BiometricAuthenticationResult`` on the main queue. The delegator callbacks are
    /// still invoked alongside the completion handler.
    ///
    /// - Parameters:
    ///   - requestTime: The timestamp to record for this authentication request.
    ///   - completion: A closure called on the main queue with the authentication result.
    public func authenticate(_ requestTime: Date, completion: @escaping @Sendable (BiometricAuthenticationResult) -> Void) {
        guard !isAuthRequestInProcess else { return }
        if let previous = previousAuthenticationTime,
           requestor.preferredAuthenticationAllowableReuseDuration() > 0,
           requestTime.timeIntervalSince(previous) < requestor.preferredAuthenticationAllowableReuseDuration() {
            notifyAuth(true, error: nil, completion: completion)
            return
        }
        isAuthRequestInProcess = true
        validateAuthenticationRequest(requestTime, completion: completion)
    }
    
    /// Validates and presents the system biometric prompt using the requestor's configuration.
    ///
    /// - Parameters:
    ///   - requestTime: The timestamp to record for this authentication request.
    ///   - completion: An optional closure called on the main queue with the authentication result.
    private func validateAuthenticationRequest(_ requestTime: Date, completion: (@Sendable (BiometricAuthenticationResult) -> Void)? = nil) {
        guard requestor.canPerformAuthentication() else {
            defer {
                self.isAuthRequestInProcess = false
                self.previousAuthenticationTime = requestTime
            }
            self.notifyAuth(true, error: nil, completion: completion)
            return
        }
        self.context = LAContext()
        self.context?.localizedFallbackTitle = self.requestor.preferredAuthenticationFallbackTitle()
        context?.evaluatePolicy(self.requestor.preferredAuthenticationPolicy().contextPolicy, localizedReason: self.requestor.preferredAuthenticationReason()) { [weak self] (success, error) in
            defer {
                self?.context = nil
                self?.isAuthRequestInProcess = false
                if success {
                    self?.previousAuthenticationTime = requestTime
                }
            }
            self?.notifyAuth(success, error: error, completion: completion)
        }
    }
    
    /// Cancels any in-progress authentication request and invalidates the current `LAContext`.
    public func cancelAuthentication() {
        self.context?.invalidate()
        self.context = nil
    }
    
    /// Invalidates the stored timestamp of the most recent successful authentication,
    /// forcing fresh biometric verification on the next call to ``authenticate(_:)``.
    public func invalidateRecentBiometricAuthenticationStamp() {
        self.previousAuthenticationTime = nil
    }
    
    /// Dispatches the authentication result to the delegator and optional completion handler on the main queue.
    ///
    /// - Parameters:
    ///   - success: Whether the authentication attempt succeeded.
    ///   - error: The error returned by the LocalAuthentication framework, or `nil` on success.
    ///   - completion: An optional closure called with the corresponding ``BiometricAuthenticationResult``.
    private func notifyAuth(_ success: Bool, error: Error?, completion: (@Sendable (BiometricAuthenticationResult) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            if success {
                completion?(.success)
                self?.delegator.authenticated()
            }else {
                let contextError = error as? LAError
                completion?(.failure(.init(contextError)))
                self?.delegator.authenticationFailed(with: .init(contextError))
            }
        }
    }
    
    /// Notifies the delegator on the main queue when the in-process state changes.
    ///
    /// This method is a no-op if `value` and `newValue` are equal.
    ///
    /// - Parameters:
    ///   - value: The previous value of ``isAuthRequestInProcess``.
    ///   - newValue: The new value of ``isAuthRequestInProcess``.
    private func handleRequestInProcessChange(from value: Bool, to newValue: Bool) {
        guard value != newValue else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.delegator.authenticationRequestInProcess(didChange: value, to: newValue)
        }
    }
}

