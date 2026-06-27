//
//  BiometricAuthManager.swift
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
import LocalAuthentication
import BiometricAuthInterface
import SwiftConcurrency


/// The concrete implementation of ``BiometricAuthentication`` that manages Face ID and Touch ID
/// authentication using the LocalAuthentication framework.
///
/// `BiometricAuthManager` coordinates the full biometric lifecycle:
/// 1. Evaluates device capabilities and user permissions.
/// 2. Presents the system biometric prompt configured by a ``BiometricAuthenticationRequestor``.
/// 3. Delivers results to a ``BiometricAuthenticationDelegator`` on the queue chosen by the requestor.
/// 4. Supports authentication reuse within a configurable time window.
///
/// Mutable instance state (`context`, `isAuthRequestInProcess`, `previousAuthenticationTime`) is
/// held inside a `ConcurrencySafeContainer` — at runtime it picks the best locking primitive
/// available (`Mutex` on iOS 18+ / `OSAllocatedUnfairLock` on iOS 16+ / `NSLock` otherwise).
///
/// The `requestor` and `delegator` are held *outside* the lock as `weak let` properties. A
/// `weak let` is immutable from the program's perspective — only the Swift runtime zeroes it
/// (atomically) when the referent deallocates — so it is `Sendable`-safe without an
/// `nonisolated(unsafe)` annotation, needs no lock, and avoids an extra lock acquisition on
/// every callback site. The class is fully `Sendable` via the protocol's conformance.
///
/// ```swift
/// let manager = BiometricAuthManager(
///     requestor: myRequestor,
///     delegator: myDelegate
/// )
///
/// if manager.availableAuthenticationType != .none {
///     manager.authenticate(Date())
/// }
/// ```
public final class BiometricAuthManager: BiometricAuthentication {

    // MARK: - Lock-Protected State

    /// The lock-protected portion of the manager's state.
    ///
    /// `requestor` and `delegator` are intentionally *not* part of this struct — they're held
    /// at the class level as `weak let` because a `weak let` reference is immutable from the
    /// program's perspective (only the runtime zeroes it, atomically) and so needs no lock
    /// protection. Keeping them outside avoids an extra lock acquisition every time we read
    /// the requestor's config or notify the delegator.
    ///
    /// `LAContext` is not `Sendable`, so access touching `context` uses `withLockUnchecked`;
    /// the Sendable-typed fields use `withLock`.
    private struct State {
        
        /// The current `LAContext` used for an in-progress authentication, or `nil` when idle.
        var context: LAContext?
        
        /// A Boolean value indicating whether an authentication request is currently in progress.
        var isAuthRequestInProcess: Bool = false
        
        /// The timestamp of the most recent successful authentication, used for reuse duration checks.
        var previousAuthenticationTime: Date?
    }
    
    /// The state that manage thread safe mutating operations.
    private let state: any ConcurrencyContainerProtocol<State> = ConcurrencySafeContainer(.init())
    
    /// The requestor that provides authentication configuration.
    ///
    /// Held as `weak let` rather than inside ``state`` because the Swift
    /// runtime guarantees atomic weak reference reads — no lock is required to access this
    /// safely from any thread.
    weak let requestor: (any BiometricAuthenticationRequestor)?

    /// The delegator that receives authentication outcome callbacks.
    ///
    /// Held as `weak let` rather than inside ``state`` because the Swift
    /// runtime guarantees atomic weak reference reads — no lock is required to access this
    /// safely from any thread.
    weak let delegator: (any BiometricAuthenticationDelegator)?

    
    // MARK: - Public Accessors

    /// A Boolean value indicating whether an authentication request is currently in progress.
    public var isAuthRequestInProcess: Bool {
        state.withLock { $0.isAuthRequestInProcess }
    }

    /// The date and time of the most recent authentication request, or `nil` if no request has been made.
    public var previousAuthenticationRequestTime: Date? {
        state.withLock { $0.previousAuthenticationTime }
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
    public required init(requestor: any BiometricAuthenticationRequestor,
                         delegator: any BiometricAuthenticationDelegator) {
        self.requestor = requestor
        self.delegator = delegator
    }
}

// MARK: - BiometricAuthentication Conformance

extension BiometricAuthManager {

    /// The type of biometric authentication available on the current device.
    ///
    /// Evaluates a fresh `LAContext` each time it is accessed to determine whether Face ID,
    /// Touch ID, or no biometry is available, along with the user's permission status.
    public var availableAuthenticationType: BiometricAuthenticationType {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available.
        // If FaceID access is disabled, `canEvaluatePolicy` returns `false` and `LAError.biometryNotAvailable` is assigned to error.
        let isEvaluateSuccess = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        guard error == nil else { return .none }

        // Optic ID (`LABiometryType.opticID`) is iOS 17+ / macOS 14+ / visionOS 1+.
        // On older deployment targets the symbol exists but the runtime never returns it.
        if #available(iOS 17.0, macOS 14.0, *), context.biometryType == .opticID {
            return .opticIdentification(permitted: isEvaluateSuccess)
        }

        switch context.biometryType {
        case .faceID:
            return .faceIdentification(permitted: isEvaluateSuccess)
        case .touchID:
            return .touchIdentification(permitted: isEvaluateSuccess)
        default:
            return .none
        }
    }

    /// A Boolean value indicating whether the user has granted permission to use biometric authentication.
    public var isAuthenticationPermitted: Bool {
        switch availableAuthenticationType {
        case .faceIdentification(let permitted), .touchIdentification(let permitted), .opticIdentification(let permitted):
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
        authenticateInternal(requestTime, completion: nil)
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
    public func authenticate(_ requestTime: Date,
                             completion: @escaping @Sendable (BiometricAuthenticationResult) -> Void) {
        authenticateInternal(requestTime, completion: completion)
    }

    /// Cancels any in-progress authentication request and invalidates the current `LAContext`.
    public func cancelAuthentication() {
        let outcome: (context: LAContext?, wasInProgress: Bool) = state.withLockUnchecked { state in
            let ctx = state.context
            let was = state.isAuthRequestInProcess
            state.context = nil
            state.isAuthRequestInProcess = false
            return (ctx, was)
        }
        outcome.context?.invalidate()
        if outcome.wasInProgress {
            notifyRequestInProcessChange(from: true, to: false)
        }
    }

    /// Invalidates the stored timestamp of the most recent successful authentication,
    /// forcing fresh biometric verification on the next call to ``authenticate(_:)``.
    public func invalidateRecentBiometricAuthenticationStamp() {
        state.withLock { $0.previousAuthenticationTime = nil }
    }
}

// MARK: - Private Implementation

extension BiometricAuthManager {

    private enum Decision {
        case alreadyInProgress
        case reuseHit
        case claimed
    }

    /// Atomically decides whether to skip, reuse, or claim the in-progress slot, then routes accordingly.
    ///
    /// - Parameters:
    ///   - requestTime: The timestamp to record for this authentication request.
    ///   - completion: An optional closure called on the main queue with the authentication result.
    private func authenticateInternal(_ requestTime: Date,
                                      completion: (@Sendable (BiometricAuthenticationResult) -> Void)?) {
        
        let reuse = requestor?.preferredAuthenticationAllowableReuseDuration() ?? 0

        // Atomically check reuse window + claim the slot in one critical section.
        let decision: Decision = state.withLock { state in
            if state.isAuthRequestInProcess { return .alreadyInProgress }
            if let previous = state.previousAuthenticationTime,
               reuse > 0,
               requestTime.timeIntervalSince(previous) < reuse {
                return .reuseHit
            }
            state.isAuthRequestInProcess = true
            return .claimed
        }

        switch decision {
        case .alreadyInProgress:
            return
        case .reuseHit:
            notifyAuth(true, error: nil, completion: completion)
        case .claimed:
            notifyRequestInProcessChange(from: false, to: true)
            validateAuthenticationRequest(requestTime, completion: completion)
        }
    }

    /// Validates the requestor's configuration and presents the system biometric prompt.
    ///
    /// - Parameters:
    ///   - requestTime: The timestamp to record for this authentication request.
    ///   - completion: An optional closure called on the main queue with the authentication result.
    private func validateAuthenticationRequest(_ requestTime: Date,
                                               completion: (@Sendable (BiometricAuthenticationResult) -> Void)?) {
        guard let requestor, requestor.canPerformAuthentication() else {
            defer {
                state.withLock { state in
                    state.previousAuthenticationTime = requestTime
                    state.context = nil
                    state.isAuthRequestInProcess = false
                }
                notifyRequestInProcessChange(from: true, to: false)
            }
            notifyAuth(true, error: nil, completion: completion)
            return
        }

        // Snapshot the entire requestor configuration outside the lock.
        let policy = requestor.preferredAuthenticationPolicy().contextPolicy
        let reason = requestor.preferredAuthenticationReason()
        let fallbackTitle = requestor.preferredAuthenticationFallbackTitle()

        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle
        state.withLockUnchecked { $0.context = context }

        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, error in
            guard let self else { return }
            defer {
                self.state.withLockUnchecked { state in
                    if success {
                        state.previousAuthenticationTime = requestTime
                    }
                    state.context = nil
                    state.isAuthRequestInProcess = false
                }
                self.notifyRequestInProcessChange(from: true, to: false)
            }
            self.notifyAuth(success, error: error, completion: completion)
        }
    }

    /// Dispatches the authentication result to the delegator and optional completion handler on the main queue.
    ///
    /// - Parameters:
    ///   - success: Whether the authentication attempt succeeded.
    ///   - error: The error returned by the LocalAuthentication framework, or `nil` on success.
    ///   - completion: An optional closure called with the corresponding ``BiometricAuthenticationResult``.
    private func notifyAuth(_ success: Bool,
                            error: Error?,
                            completion: (@Sendable (BiometricAuthenticationResult) -> Void)?) {
        requestor?.preferredDelegateQueue.async { [weak self] in
            if success {
                completion?(.success)
                self?.delegator?.authenticated()
            } else {
                let contextError = error as? LAError
                completion?(.failure(.init(contextError)))
                self?.delegator?.authenticationFailed(with: .init(contextError))
            }
        }
    }

    /// Notifies the delegator on the main queue when the in-process state changes.
    ///
    /// This method is a no-op if `oldValue` and `newValue` are equal.
    ///
    /// - Parameters:
    ///   - oldValue: The previous value of `isAuthRequestInProcess`.
    ///   - newValue: The new value of `isAuthRequestInProcess`.
    private func notifyRequestInProcessChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        requestor?.preferredDelegateQueue.async { [weak self] in
            self?.delegator?.authenticationRequestInProcess(didChange: oldValue, to: newValue)
        }
    }
}
