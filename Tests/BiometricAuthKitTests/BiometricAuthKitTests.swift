import Testing
import LocalAuthentication
@testable import BiometricAuthInterface
@testable import BiometricAuth

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

    @Test("opticIdentification cases with different permitted values are not equal")
    func opticIdentificationEquality() {
        let permitted = BiometricAuthenticationType.opticIdentification(permitted: true)
        let notPermitted = BiometricAuthenticationType.opticIdentification(permitted: false)
        #expect(permitted != notPermitted)
    }

    @Test("opticIdentification is distinct from face, touch, and none")
    func opticIdentificationIsDistinct() {
        let optic = BiometricAuthenticationType.opticIdentification(permitted: true)
        #expect(optic != .faceIdentification(permitted: true))
        #expect(optic != .touchIdentification(permitted: true))
        #expect(optic != .none)
    }

    @Test("hashable conformance produces consistent hashes")
    func hashableConformance() {
        let a = BiometricAuthenticationType.faceIdentification(permitted: true)
        let b = BiometricAuthenticationType.faceIdentification(permitted: true)
        #expect(a.hashValue == b.hashValue)

        let c = BiometricAuthenticationType.opticIdentification(permitted: true)
        let d = BiometricAuthenticationType.opticIdentification(permitted: true)
        #expect(c.hashValue == d.hashValue)
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

private final class MockRequestor: BiometricAuthenticationRequestor, @unchecked Sendable {
    var canPerform: Bool = true
    var reuseDuration: TimeInterval = 0
    var reason: String = "Authenticate"
    var fallbackTitle: String = "Use Passcode"
    var policy: BiometricAuthenticationPolicy = .ownerAuthentication
    var customQueue: DispatchQueue?

    convenience init(canPerform: Bool = true, reuseDuration: TimeInterval = 0) {
        self.init()
        self.canPerform = canPerform
        self.reuseDuration = reuseDuration
    }

    var preferredDelegateQueue: DispatchQueue { customQueue ?? .main }
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
        let requestor = MockRequestor()
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
        manager.cancelAuthentication()
        #expect(manager.isAuthRequestInProcess == false)
    }

    @Test("invalidateRecentBiometricAuthenticationStamp clears timestamp")
    func invalidateStamp() {
        let requestor = MockRequestor()
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
        manager.invalidateRecentBiometricAuthenticationStamp()
        #expect(manager.previousAuthenticationRequestTime == nil)
    }

    @Test("isFacialBiometricAuthenticationAvailable returns false when no biometry")
    func facialAuthNotAvailableWithoutBiometry() {
        let requestor = MockRequestor()
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
        let authType = manager.availableAuthenticationType
        if authType == .none {
            #expect(manager.isFacialBiometricAuthenticationAvailable == false)
        }
    }

    @Test("isAuthenticationSupported returns false when availableAuthenticationType is .none")
    func supportedMatchesAvailableType() {
        let requestor = MockRequestor()
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
        let authType = manager.availableAuthenticationType
        if authType == .none {
            #expect(manager.isAuthenticationSupported == false)
        }
    }

    @Test("isAuthenticationPermitted returns false when availableAuthenticationType is .none")
    func permittedMatchesAvailableType() {
        let requestor = MockRequestor()
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
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
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.didAuthenticate == true)
    }

    @Test("authenticate with completion delivers .success when canPerform is false")
    func authCompletionDeliversSuccess() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
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
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
        #expect(manager.previousAuthenticationRequestTime == nil)
        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.didAuthenticate == true)
        #expect(manager.previousAuthenticationRequestTime != nil)
    }

    @Test("isAuthRequestInProcess transitions to true then back to false")
    func inProcessStateTransitions() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)
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
        let requestor = MockRequestor(canPerform: false, reuseDuration: 5)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

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
        let requestor = MockRequestor(canPerform: false, reuseDuration: 5)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

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
        let requestor = MockRequestor(canPerform: false, reuseDuration: 5)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

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
        let requestor = MockRequestor(canPerform: false, reuseDuration: 5)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

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
        let requestor = MockRequestor(canPerform: false, reuseDuration: 0)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

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

// MARK: - Delegator Delivery Tests

@Suite("Delegator Delivery")
struct DelegatorDeliveryTests {

    @Test("delegator receives authenticated callback when using completion API")
    func delegatorAuthenticatedWithCompletionAPI() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BiometricAuthenticationResult, Never>) in
            manager.authenticate(Date()) { result in
                continuation.resume(returning: result)
            }
        }

        if case .success = result {
            #expect(delegator.didAuthenticate == true)
            #expect(delegator.authenticateCount == 1)
            #expect(delegator.authenticationError == nil)
        } else {
            Issue.record("Expected .success")
        }
    }

    @Test("delegator receives inProcess changes when using completion API")
    func delegatorInProcessChangesWithCompletionAPI() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        _ = await withCheckedContinuation { (continuation: CheckedContinuation<BiometricAuthenticationResult, Never>) in
            manager.authenticate(Date()) { result in
                continuation.resume(returning: result)
            }
        }

        #expect(delegator.inProcessChanges.count == 2)
        #expect(delegator.inProcessChanges[0].from == false)
        #expect(delegator.inProcessChanges[0].to == true)
        #expect(delegator.inProcessChanges[1].from == true)
        #expect(delegator.inProcessChanges[1].to == false)
    }

    @Test("delegator receives authenticated callback via delegate-only path")
    func delegatorAuthenticatedViaDelegateOnly() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        manager.authenticate(Date())
        await drainMainQueue()

        #expect(delegator.didAuthenticate == true)
        #expect(delegator.authenticateCount == 1)
        #expect(delegator.authenticationError == nil)
    }

    @Test("delegator and completion handler both fire for reuse window shortcut")
    func delegatorAndCompletionBothFireOnReuse() async {
        let requestor = MockRequestor(canPerform: false, reuseDuration: 5)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        // First auth to set timestamp
        manager.authenticate(Date())
        await drainMainQueue()
        delegator.reset()

        // Second auth within reuse window using completion API
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<BiometricAuthenticationResult, Never>) in
            manager.authenticate(Date()) { result in
                continuation.resume(returning: result)
            }
        }

        if case .success = result {
            #expect(delegator.didAuthenticate == true)
            #expect(delegator.authenticateCount == 1)
        } else {
            Issue.record("Expected .success")
        }
        // Reuse path skips isAuthRequestInProcess, so no in-process changes
        #expect(delegator.inProcessChanges.isEmpty)
    }

    @Test("delegator authenticated count increments across multiple calls")
    func delegatorCountIncrementsAcrossCalls() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.authenticateCount == 1)

        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.authenticateCount == 2)

        manager.authenticate(Date())
        await drainMainQueue()
        #expect(delegator.authenticateCount == 3)
    }
}

// MARK: - Concurrency Safety Tests

@Suite("Concurrency Safety")
struct ConcurrencySafetyTests {

    @Test("manager survives concurrent authenticate calls without crashing")
    func concurrentAuthenticateCalls() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { manager.authenticate(Date()) }
            }
        }
        await drainMainQueue()

        // After all races settle, the in-progress slot must be released.
        #expect(manager.isAuthRequestInProcess == false)
        // At least one call has to have made it through.
        #expect(delegator.authenticateCount >= 1)
    }

    @Test("manager survives cancelAuthentication racing with authenticate")
    func concurrentCancelAndAuthenticate() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<25 {
                group.addTask { manager.authenticate(Date()) }
                group.addTask { manager.cancelAuthentication() }
            }
        }
        await drainMainQueue()

        #expect(manager.isAuthRequestInProcess == false)
    }

    @Test("manager survives invalidateStamp racing with authenticate")
    func concurrentInvalidateAndAuthenticate() async {
        let requestor = MockRequestor(canPerform: false, reuseDuration: 60)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<25 {
                group.addTask { manager.authenticate(Date()) }
                group.addTask { manager.invalidateRecentBiometricAuthenticationStamp() }
            }
        }
        await drainMainQueue()

        #expect(manager.isAuthRequestInProcess == false)
    }

    @Test("concurrent property reads do not crash or deadlock")
    func concurrentPropertyReads() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = manager.isAuthRequestInProcess
                    _ = manager.previousAuthenticationRequestTime
                    _ = manager.availableAuthenticationType
                    _ = manager.isAuthenticationSupported
                    _ = manager.isAuthenticationPermitted
                    _ = manager.isFacialBiometricAuthenticationAvailable
                }
            }
        }
    }

    @Test("manager can be passed across detached task boundaries")
    func sendableConformanceAcrossTasks() async {
        let requestor = MockRequestor(canPerform: false)
        let delegator = MockDelegator()
        let manager: BiometricAuthentication = BiometricAuthManager(requestor: requestor, delegator: delegator)

        // Passing `manager` into a detached task only compiles if it is `Sendable`.
        await Task.detached {
            manager.authenticate(Date())
        }.value
        await drainMainQueue()

        #expect(delegator.authenticateCount == 1)
    }

    @Test("concurrent completion-handler authenticate calls all receive a result")
    func concurrentCompletionHandlers() async {
        let requestor = MockRequestor(canPerform: false, reuseDuration: 60)
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        // Prime the reuse window so concurrent calls take the reuse-hit shortcut deterministically.
        manager.authenticate(Date())
        await drainMainQueue()
        delegator.reset()

        let resultCount: Int = await withTaskGroup(of: BiometricAuthenticationResult.self, returning: Int.self) { group in
            for _ in 0..<30 {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<BiometricAuthenticationResult, Never>) in
                        manager.authenticate(Date()) { result in
                            continuation.resume(returning: result)
                        }
                    }
                }
            }
            var count = 0
            for await result in group {
                if case .success = result { count += 1 }
            }
            return count
        }

        #expect(resultCount == 30)
        #expect(manager.isAuthRequestInProcess == false)
    }
}

// MARK: - AuthRequestor Default Implementation Tests

private final class MinimalRequestor: BiometricAuthenticationRequestor {
    func preferredAuthenticationReason() -> String { "Test reason" }
}

@Suite("AuthRequestor Defaults")
struct AuthRequestorDefaultTests {

    @Test("canPerformAuthentication defaults to true")
    func defaultCanPerform() {
        #expect(MinimalRequestor().canPerformAuthentication() == true)
    }

    @Test("preferredAuthenticationAllowableReuseDuration defaults to zero")
    func defaultReuseDuration() {
        #expect(MinimalRequestor().preferredAuthenticationAllowableReuseDuration() == 0)
    }

    @Test("preferredAuthenticationPolicy defaults to ownerAuthentication")
    func defaultPolicy() {
        #expect(MinimalRequestor().preferredAuthenticationPolicy() == .ownerAuthentication)
    }

    @Test("preferredAuthenticationFallbackTitle defaults to passcode prompt")
    func defaultFallbackTitle() {
        #expect(MinimalRequestor().preferredAuthenticationFallbackTitle() == "Please use your passcode.")
    }

    @Test("preferredDelegateQueue defaults to main")
    func defaultDelegateQueue() {
        #expect(MinimalRequestor().preferredDelegateQueue === DispatchQueue.main)
    }
}

// MARK: - Delegate Queue Dispatch Tests

@Suite("Delegate Queue Dispatch")
struct DelegateQueueDispatchTests {

    @Test("delegator callback runs on requestor's preferredDelegateQueue")
    func customDelegateQueueDelivery() async {
        let key = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: "test.custom.delegate.queue")
        queue.setSpecific(key: key, value: "custom-marker")

        let requestor = MockRequestor(canPerform: false)
        requestor.customQueue = queue
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        let marker: String? = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            delegator.onAuthenticated = {
                continuation.resume(returning: DispatchQueue.getSpecific(key: key))
            }
            manager.authenticate(Date())
        }

        #expect(marker == "custom-marker")
    }

    @Test("completion handler runs on requestor's preferredDelegateQueue")
    func customDelegateQueueDeliversCompletion() async {
        let key = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: "test.custom.delegate.queue.completion")
        queue.setSpecific(key: key, value: "completion-marker")

        let requestor = MockRequestor(canPerform: false)
        requestor.customQueue = queue
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        let marker: String? = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            manager.authenticate(Date()) { _ in
                continuation.resume(returning: DispatchQueue.getSpecific(key: key))
            }
        }

        #expect(marker == "completion-marker")
    }

    @Test("default (main) queue is used when requestor does not override")
    func defaultMainQueueDelivery() async {
        let key = DispatchSpecificKey<String>()
        DispatchQueue.main.setSpecific(key: key, value: "main-marker")
        defer { DispatchQueue.main.setSpecific(key: key, value: nil) }

        let requestor = MockRequestor(canPerform: false) // no customQueue set
        let delegator = MockDelegator()
        let manager = BiometricAuthManager(requestor: requestor, delegator: delegator)

        let marker: String? = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            delegator.onAuthenticated = {
                continuation.resume(returning: DispatchQueue.getSpecific(key: key))
            }
            manager.authenticate(Date())
        }

        #expect(marker == "main-marker")
    }
}

// MARK: - Additional BiometricAuthenticationError Tests

@Suite("BiometricAuthenticationError Extended")
struct BiometricAuthenticationErrorExtendedTests {

    @Test("init with unknown LAError code returns .other")
    func unknownCodeReturnsOther() {
        let laError = LAError(LAError.Code(rawValue: -99)!)
        #expect(BiometricAuthenticationError(laError) == .other)
    }

    @Test("different error cases are not equal")
    func differentCasesNotEqual() {
        #expect(BiometricAuthenticationError.failed != .canceledByUser)
        #expect(BiometricAuthenticationError.canceledByUser != .fallback)
        #expect(BiometricAuthenticationError.fallback != .canceledBySystem)
        #expect(BiometricAuthenticationError.canceledBySystem != .passcodeNotSet)
        #expect(BiometricAuthenticationError.passcodeNotSet != .biometryNotAvailable)
        #expect(BiometricAuthenticationError.biometryNotAvailable != .biometryNotEnrolled)
        #expect(BiometricAuthenticationError.biometryNotEnrolled != .biometryLockedout)
        #expect(BiometricAuthenticationError.biometryLockedout != .other)
        #expect(BiometricAuthenticationError.other != .failed)
    }

    @Test("errorDescription content for remaining cases")
    func remainingErrorDescriptions() {
        #expect(BiometricAuthenticationError.fallback.errorDescription?.contains("fallback") == true)
        #expect(BiometricAuthenticationError.canceledBySystem.errorDescription?.contains("canceled") == true)
        #expect(BiometricAuthenticationError.biometryNotAvailable.errorDescription?.contains("not available") == true)
        #expect(BiometricAuthenticationError.biometryNotEnrolled.errorDescription?.contains("enrolled") == true)
        #expect(BiometricAuthenticationError.biometryLockedout.errorDescription?.contains("locked") == true)
        #expect(BiometricAuthenticationError.other.errorDescription?.contains("try again") == true)
    }
}

// MARK: - Additional BiometricAuthenticationType Tests

@Suite("BiometricAuthenticationType Collections")
struct BiometricAuthenticationTypeCollectionTests {

    @Test("Set deduplicates identical cases")
    func setDeduplication() {
        let set: Set<BiometricAuthenticationType> = [
            .faceIdentification(permitted: true),
            .faceIdentification(permitted: true),
            .touchIdentification(permitted: false),
        ]
        #expect(set.count == 2)
    }

    @Test("Set distinguishes all four case families")
    func setDistinguishesAllCases() {
        let set: Set<BiometricAuthenticationType> = [
            .faceIdentification(permitted: true),
            .touchIdentification(permitted: true),
            .opticIdentification(permitted: true),
            .none,
        ]
        #expect(set.count == 4)
    }

    @Test("Set distinguishes same case with different associated values")
    func setDistinguishesDifferentPermissions() {
        let set: Set<BiometricAuthenticationType> = [
            .faceIdentification(permitted: true),
            .faceIdentification(permitted: false),
        ]
        #expect(set.count == 2)
    }
}

// MARK: - Additional BiometricAuthenticationPolicy Tests

@Suite("BiometricAuthenticationPolicy Equality")
struct BiometricAuthenticationPolicyEqualityTests {

    @Test("same policy cases are equal")
    func sameCasesEqual() {
        #expect(BiometricAuthenticationPolicy.ownerAuthentication == .ownerAuthentication)
        #expect(BiometricAuthenticationPolicy.ownerAuthenticationWithBiometrics == .ownerAuthenticationWithBiometrics)
    }

    @Test("different policy cases are not equal")
    func differentCasesNotEqual() {
        #expect(BiometricAuthenticationPolicy.ownerAuthentication != .ownerAuthenticationWithBiometrics)
    }
}
