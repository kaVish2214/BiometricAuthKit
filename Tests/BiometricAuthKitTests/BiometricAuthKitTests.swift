import Testing
import LocalAuthentication
@testable import BiometricAuthKit

// MARK: - BiometricAuthenticationType Tests

@Suite("BiometricAuthenticationType")
struct BiometricAuthenticationTypeTests {

    @Test("faceIdentification cases with different permitted values are not equal")
    func faceIdentificationEquality() {
        let permitted = BiometricAuthenticationType.faceIdentification(permitted: true)
        let notPermitted = BiometricAuthenticationType.faceIdentification(permitted: false)
        #expect(permitted != notPermitted)
    }

    @Test("touchIdentification cases with different permitted values are not equal")
    func touchIdentificationEquality() {
        let permitted = BiometricAuthenticationType.touchIdentification(permitted: true)
        let notPermitted = BiometricAuthenticationType.touchIdentification(permitted: false)
        #expect(permitted != notPermitted)
    }

    @Test("same cases with same values are equal")
    func sameCasesAreEqual() {
        #expect(BiometricAuthenticationType.faceIdentification(permitted: true) == .faceIdentification(permitted: true))
        #expect(BiometricAuthenticationType.touchIdentification(permitted: false) == .touchIdentification(permitted: false))
        #expect(BiometricAuthenticationType.none == .none)
    }

    @Test("different biometric types are not equal")
    func differentTypesAreNotEqual() {
        #expect(BiometricAuthenticationType.faceIdentification(permitted: true) != .touchIdentification(permitted: true))
        #expect(BiometricAuthenticationType.faceIdentification(permitted: true) != .none)
        #expect(BiometricAuthenticationType.touchIdentification(permitted: true) != .none)
    }

    @Test("hashable conformance produces consistent hashes")
    func hashableConformance() {
        let a = BiometricAuthenticationType.faceIdentification(permitted: true)
        let b = BiometricAuthenticationType.faceIdentification(permitted: true)
        #expect(a.hashValue == b.hashValue)
    }
}

// MARK: - BiometricAuthenticationError Tests

@Suite("BiometricAuthenticationError")
struct BiometricAuthenticationErrorTests {

    @Test("init with nil returns .other")
    func initWithNilReturnsOther() {
        let error = BiometricAuthenticationError(nil)
        #expect(error == .other)
    }

    @Test("init maps LAError codes correctly", arguments: [
        (LAError.Code.authenticationFailed, BiometricAuthenticationError.failed),
        (LAError.Code.userCancel, BiometricAuthenticationError.canceledByUser),
        (LAError.Code.userFallback, BiometricAuthenticationError.fallback),
        (LAError.Code.systemCancel, BiometricAuthenticationError.canceledBySystem),
        (LAError.Code.passcodeNotSet, BiometricAuthenticationError.passcodeNotSet),
        (LAError.Code.biometryNotAvailable, BiometricAuthenticationError.biometryNotAvailable),
        (LAError.Code.biometryNotEnrolled, BiometricAuthenticationError.biometryNotEnrolled),
        (LAError.Code.biometryLockout, BiometricAuthenticationError.biometryLockedout),
    ])
    func initMapsLAErrorCodes(code: LAError.Code, expected: BiometricAuthenticationError) {
        let laError = LAError(code)
        let error = BiometricAuthenticationError(laError)
        #expect(error == expected)
    }

    @Test("every case has a non-nil localized description")
    func allCasesHaveLocalizedDescription() {
        let allCases: [BiometricAuthenticationError] = [
            .failed, .canceledByUser, .fallback, .canceledBySystem,
            .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled,
            .biometryLockedout, .other
        ]
        for error in allCases {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("errorDescription returns expected strings for key cases")
    func errorDescriptionContent() {
        #expect(BiometricAuthenticationError.failed.errorDescription?.contains("failed") == true)
        #expect(BiometricAuthenticationError.canceledByUser.errorDescription?.contains("canceled by user") == true)
        #expect(BiometricAuthenticationError.passcodeNotSet.errorDescription?.contains("passcode") == true)
    }
}

// MARK: - BiometricAuthenticationResult Tests

@Suite("BiometricAuthenticationResult")
struct BiometricAuthenticationResultTests {

    @Test("success case can be constructed")
    func successCase() {
        let result = BiometricAuthenticationResult.success
        if case .success = result {
            // pass
        } else {
            Issue.record("Expected .success")
        }
    }

    @Test("failure case wraps the correct error")
    func failureCase() {
        let result = BiometricAuthenticationResult.failure(.canceledByUser)
        if case .failure(let error) = result {
            #expect(error == .canceledByUser)
        } else {
            Issue.record("Expected .failure")
        }
    }
}

// MARK: - BiometricAuthenticationPolicy Tests

@Suite("BiometricAuthenticationPolicy")
struct BiometricAuthenticationPolicyTests {

    @Test("ownerAuthenticationWithBiometrics maps to deviceOwnerAuthenticationWithBiometrics")
    func biometricsOnlyPolicy() {
        let policy = BiometricAuthenticationPolicy.ownerAuthenticationWithBiometrics
        #expect(policy.contextPolicy == .deviceOwnerAuthenticationWithBiometrics)
    }

    @Test("ownerAuthentication maps to deviceOwnerAuthentication")
    func ownerAuthenticationPolicy() {
        let policy = BiometricAuthenticationPolicy.ownerAuthentication
        #expect(policy.contextPolicy == .deviceOwnerAuthentication)
    }
}

// MARK: - BiometricAuthManager Tests

private struct MockRequestor: BiometricAuthenticationRequestor {
    var canPerform: Bool = true
    var reuseDuration: TimeInterval = 0
    var reason: String = "Authenticate"
    var fallbackTitle: String = "Use Passcode"
    var policy: BiometricAuthenticationPolicy = .ownerAuthentication

    func canPerformAuthentication() -> Bool { canPerform }
    func preferredAuthenticationAllowableReuseDuration() -> TimeInterval { reuseDuration }
    func preferredAuthenticationReason() -> String { reason }
    func preferredAuthenticationFallbackTitle() -> String { fallbackTitle }
    func preferredAuthenticationPolicy() -> BiometricAuthenticationPolicy { policy }
}

private final class MockDelegator: BiometricAuthenticationDelegator, @unchecked Sendable {
    var didAuthenticate = false
    var authenticateCount = 0
    var authenticationError: BiometricAuthenticationError?
    var inProcessChanges: [(from: Bool, to: Bool)] = []
    var onAuthenticated: (() -> Void)?
    var onFailed: ((BiometricAuthenticationError) -> Void)?

    func authenticated() {
        didAuthenticate = true
        authenticateCount += 1
        onAuthenticated?()
    }

    func authenticationFailed(with error: BiometricAuthenticationError) {
        authenticationError = error
        onFailed?(error)
    }

    func authenticationRequestInProcess(didChange from: Bool, to: Bool) {
        inProcessChanges.append((from: from, to: to))
    }

    func reset() {
        didAuthenticate = false
        authenticateCount = 0
        authenticationError = nil
        inProcessChanges = []
    }
}

@Suite("BiometricAuthManager")
struct BiometricAuthManagerTests {

    @Test("initial state is correct after initialization")
    func initialState() {
        let requestor = MockRequestor()
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        #expect(manager.isAuthRequestInProcess == false)
        #expect(manager.previousAuthenticationRequestTime == nil)
    }

    @Test("cancelAuthentication does not crash when no request is in progress")
    func cancelWithoutActiveRequest() {
        let manager = BiometricAuthManager(requestor: MockRequestor(), delegator: MockDelegator())
        manager.cancelAuthentication()
        #expect(manager.isAuthRequestInProcess == false)
    }

    @Test("invalidateRecentBiometricAuthenticationStamp clears timestamp")
    func invalidateStamp() {
        let manager = BiometricAuthManager(requestor: MockRequestor(), delegator: MockDelegator())
        manager.invalidateRecentBiometricAuthenticationStamp()
        #expect(manager.previousAuthenticationRequestTime == nil)
    }

    @Test("isFacialBiometricAuthenticationAvailable returns false when no biometry")
    func facialAuthNotAvailableWithoutBiometry() {
        let manager = BiometricAuthManager(requestor: MockRequestor(), delegator: MockDelegator())
        let authType = manager.availableAuthenticationType
        if authType == .none {
            #expect(manager.isFacialBiometricAuthenticationAvailable == false)
        }
    }

    @Test("isAuthenticationSupported returns false when availableAuthenticationType is .none")
    func supportedMatchesAvailableType() {
        let manager = BiometricAuthManager(requestor: MockRequestor(), delegator: MockDelegator())
        let authType = manager.availableAuthenticationType
        if authType == .none {
            #expect(manager.isAuthenticationSupported == false)
        }
    }

    @Test("isAuthenticationPermitted returns false when availableAuthenticationType is .none")
    func permittedMatchesAvailableType() {
        let manager = BiometricAuthManager(requestor: MockRequestor(), delegator: MockDelegator())
        let authType = manager.availableAuthenticationType
        if authType == .none {
            #expect(manager.isAuthenticationPermitted == false)
        }
    }
}

// MARK: - Test Helpers

/// Suspends until all previously enqueued main queue blocks have executed.
private func drainMainQueue() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            continuation.resume()
        }
    }
}

// MARK: - Authentication Flow Tests

@Suite("Authentication Flow")
struct AuthenticationFlowTests {

    @Test("authenticate succeeds when canPerformAuthentication returns false")
    func authSucceedsWhenCanPerformIsFalse() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false),
            delegator: delegator
        )
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.didAuthenticate == true)
    }

    @Test("authenticate with completion delivers .success when canPerform is false")
    func authCompletionDeliversSuccess() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false),
            delegator: delegator
        )
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BiometricAuthenticationResult, Never>) in
            manager.authenticate(Date()) { result in
                continuation.resume(returning: result)
            }
        }
        if case .success = result {
            // pass
        } else {
            Issue.record("Expected .success, got \(result)")
        }
    }

    @Test("authenticate stores timestamp after success")
    func authStoresTimestamp() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false),
            delegator: delegator
        )
        #expect(manager.previousAuthenticationRequestTime == nil)
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.didAuthenticate == true)
        #expect(manager.previousAuthenticationRequestTime != nil)
    }

    @Test("isAuthRequestInProcess transitions to true then back to false")
    func inProcessStateTransitions() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false),
            delegator: delegator
        )
        manager.authenticate(Date())
        await drainMainQueue()

        #expect(delegator.inProcessChanges.count == 2)
        #expect(delegator.inProcessChanges[0].from == false)
        #expect(delegator.inProcessChanges[0].to == true)
        #expect(delegator.inProcessChanges[1].from == true)
        #expect(delegator.inProcessChanges[1].to == false)
    }
}

// MARK: - Reuse Window Tests

@Suite("Reuse Window")
struct ReuseWindowTests {

    @Test("second auth within reuse window succeeds without re-evaluation")
    func reuseWithinWindow() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false, reuseDuration: 5),
            delegator: delegator
        )

        // First auth — goes through validateAuthenticationRequest
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.authenticateCount == 1)
        #expect(delegator.inProcessChanges.count == 2)

        delegator.reset()

        // Second auth within 5s — should take the reuse shortcut
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.authenticateCount == 1)
        // Reuse path does NOT set isAuthRequestInProcess, so no in-process changes
        #expect(delegator.inProcessChanges.isEmpty)
    }

    @Test("auth after reuse window expires goes through full evaluation")
    func authAfterWindowExpires() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false, reuseDuration: 5),
            delegator: delegator
        )

        // First auth at time T
        let firstTime = Date()
        manager.authenticate(firstTime)
        await drainMainQueue()
        delegator.reset()

        // Second auth at T+6s — outside the 5s window
        let expiredTime = firstTime.addingTimeInterval(6)
        manager.authenticate(expiredTime)
        await drainMainQueue()
        #expect(delegator.authenticateCount == 1)
        // Full evaluation path sets isAuthRequestInProcess true then false
        #expect(delegator.inProcessChanges.count == 2)
    }

    @Test("completion handler works within reuse window")
    func completionWithinReuseWindow() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false, reuseDuration: 5),
            delegator: delegator
        )

        // First auth to set the timestamp
        manager.authenticate(Date())
        await drainMainQueue()

        // Second auth within window using completion handler
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BiometricAuthenticationResult, Never>) in
            manager.authenticate(Date()) { result in
                continuation.resume(returning: result)
            }
        }
        if case .success = result {
            // pass
        } else {
            Issue.record("Expected .success, got \(result)")
        }
    }

    @Test("invalidateStamp forces re-evaluation even within reuse window")
    func invalidateStampForcesReEvaluation() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false, reuseDuration: 5),
            delegator: delegator
        )

        // First auth
        manager.authenticate(Date())
        await drainMainQueue()
        delegator.reset()

        // Invalidate the stamp
        manager.invalidateRecentBiometricAuthenticationStamp()

        // Next auth within 5s should still go through full evaluation
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.authenticateCount == 1)
        // Full evaluation path — in-process changes present
        #expect(delegator.inProcessChanges.count == 2)
    }

    @Test("reuse window of zero always requires fresh authentication")
    func zeroReuseAlwaysReEvaluates() async {
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(
            requestor: MockRequestor(canPerform: false, reuseDuration: 0),
            delegator: delegator
        )

        // First auth
        manager.authenticate(Date())
        await drainMainQueue()
        delegator.reset()

        // Second auth immediately — should still go through full evaluation
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.inProcessChanges.count == 2)
    }
}
