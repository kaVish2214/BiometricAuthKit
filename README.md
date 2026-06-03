# BiometricAuthKit

A lightweight, protocol-oriented Swift package that wraps Apple's `LocalAuthentication` framework to make Face ID and Touch ID authentication simple, testable, and dependency-injection friendly on iOS and macOS.

## Purpose & Intent

The `LocalAuthentication` framework is powerful but low-level: callers have to manage `LAContext` lifecycles, translate `LAError` codes, marshal callbacks to the main queue, and re-implement common ergonomics like "don't prompt again if the user authenticated five seconds ago" on every project.

**BiometricAuthKit** exists to solve that. It provides:

- A **clean public surface** (`BiometricAuthentication`) for performing biometric authentication, with both delegate-based and completion-handler APIs.
- A **separated interface module** (`BiometricAuthInterface`) so application code, tests, and mocks can depend on protocols and value types — never on the concrete `LocalAuthentication`-backed implementation.
- **Built-in reuse-window logic** so a previous successful authentication can be honored without re-prompting the user, configurable per request.
- **Strongly-typed errors and states** (`BiometricAuthenticationError`, `BiometricAuthenticationType`, `BiometricAuthenticationResult`, `BiometricAuthenticationPolicy`) that wrap the framework's `LAError` codes and policies into ergonomic Swift enums with `Sendable` conformance.
- **Swift 6 / strict concurrency** support — all public types are `Sendable`, and callbacks are delivered on the main queue.

## Why two products?

The package ships **two libraries**:

| Product | Contents | Depend on it when… |
|---|---|---|
| `BiometricAuthInterface` | Protocols (`BiometricAuthentication`, `BiometricAuthenticationRequestor`, `BiometricAuthenticationDelegator`) and value types (errors, results, policies, types). | You are a feature module, app layer, or test target that only needs to *talk to* a biometric authenticator without pulling in `LocalAuthentication`. |
| `BiometricAuth` | The concrete `BiometricAuthManager` implementation that drives `LAContext`. | You are the composition root (app target, DI container) and need to instantiate the real authenticator. |

This split lets feature code stay decoupled from `LocalAuthentication`, makes mocking trivial in unit tests, and keeps build times for downstream modules small.

## Requirements

- iOS 12.0+ / macOS 10.14+
- Swift 6.3 toolchain (language mode `.v6`)
- Xcode 16+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/BiometricAuthKit.git", from: "1.0.0")
]
```

Then pick the product(s) that fit each target:

```swift
.target(
    name: "MyFeature",
    dependencies: [
        .product(name: "BiometricAuthInterface", package: "BiometricAuthKit")
    ]
),
.target(
    name: "MyApp",
    dependencies: [
        "MyFeature",
        .product(name: "BiometricAuth", package: "BiometricAuthKit")
    ]
)
```

## Setup

### Info.plist — `NSFaceIDUsageDescription` (required for Face ID)

iOS terminates any app that attempts to evaluate a Face ID policy without an `NSFaceIDUsageDescription` entry. Add the key to your app target's `Info.plist` with a short, user-facing reason:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your account.</string>
```

Touch ID does not require this key, but adding it is harmless and future-proofs the app for devices that switch to Face ID.

> **Note:** This is an *app target* requirement, not a package requirement. The string is shown by the system the first time Face ID is requested.

### Ownership: retain your requestor and delegator

`BiometricAuthManager` holds both the `requestor` and `delegator` as **weak references**. If you construct them inline and let them go out of scope, callbacks will silently stop firing and authentication will appear to "do nothing." Always store them on a longer-lived owner (a view model, coordinator, or DI container):

```swift
final class LoginViewModel {
    private let requestor = LoginAuthRequestor()
    private let delegator = LoginAuthDelegator()
    private lazy var auth: BiometricAuthentication = BiometricAuthManager(
        requestor: requestor,
        delegator: delegator
    )
}
```

## Quick Start

### 1. Conform to the requestor and delegator

```swift
import BiometricAuthInterface

final class LoginAuthRequestor: BiometricAuthenticationRequestor {
    func preferredAuthenticationReason() -> String {
        "Unlock your account"
    }

    func preferredAuthenticationAllowableReuseDuration() -> TimeInterval {
        30 // skip prompt if user authenticated in the last 30s
    }

    func preferredAuthenticationPolicy() -> BiometricAuthenticationPolicy {
        .ownerAuthenticationWithBiometrics
    }
}

final class LoginAuthDelegator: BiometricAuthenticationDelegator {
    func authenticated() {
        // Route to protected content
    }

    func authenticationFailed(with error: BiometricAuthenticationError) {
        // Present error.localizedDescription
    }

    func authenticationRequestInProcess(didChange from: Bool, to: Bool) {
        // Toggle a loading indicator
    }
}
```

### 2. Drive the authenticator

```swift
import BiometricAuth
import BiometricAuthInterface

let requestor = LoginAuthRequestor()
let delegator = LoginAuthDelegator()

let auth: BiometricAuthentication = BiometricAuthManager(
    requestor: requestor,
    delegator: delegator
)

guard auth.isAuthenticationSupported, auth.isAuthenticationPermitted else {
    // Fall back to password-only flow
    return
}

auth.authenticate(Date())
```

### 3. Or use the completion-handler API

```swift
auth.authenticate(Date()) { result in
    switch result {
    case .success:
        // Proceed
    case .failure(let error):
        // Handle error
    }
}
```

## SwiftUI Example

The completion-handler API composes cleanly with SwiftUI. Wrap the authenticator in an `@Observable` model so the view re-renders on state changes, and keep the requestor/delegator alive on the model (per the ownership note above).

```swift
import SwiftUI
import BiometricAuth
import BiometricAuthInterface

@Observable
@MainActor
final class UnlockModel {
    enum State { case idle, authenticating, unlocked, failed(String) }

    private(set) var state: State = .idle

    private let requestor = LoginAuthRequestor()
    private let delegator: LoginAuthDelegator
    private lazy var auth: BiometricAuthentication = BiometricAuthManager(
        requestor: requestor,
        delegator: delegator
    )

    init() {
        self.delegator = LoginAuthDelegator()
    }

    func unlock() {
        guard auth.isAuthenticationSupported, auth.isAuthenticationPermitted else {
            state = .failed("Biometrics unavailable")
            return
        }
        state = .authenticating
        auth.authenticate(Date()) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.state = .unlocked
            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }
}

struct UnlockView: View {
    @State private var model = UnlockModel()

    var body: some View {
        VStack(spacing: 16) {
            switch model.state {
            case .idle:
                Button("Unlock with Biometrics", action: model.unlock)
            case .authenticating:
                ProgressView()
            case .unlocked:
                Text("Welcome back")
            case .failed(let message):
                Text(message).foregroundStyle(.red)
                Button("Try again", action: model.unlock)
            }
        }
        .padding()
    }
}
```

## Inspecting Device Capability

```swift
switch auth.availableAuthenticationType {
case .faceIdentification(let permitted):
    // Show a "Use Face ID" affordance, disabled when !permitted
case .touchIdentification(let permitted):
    // Show a "Use Touch ID" affordance, disabled when !permitted
case .none:
    // Hide biometric UI entirely
}
```

## Cancellation & Reuse

- `cancelAuthentication()` invalidates the in-flight `LAContext` and resets the in-process flag.
- `invalidateRecentBiometricAuthenticationStamp()` clears the cached success timestamp so the next `authenticate(_:)` call always prompts, regardless of the reuse duration.

## Concurrency Guarantees

BiometricAuthKit is designed for Swift 6 strict concurrency:

- **All public types are `Sendable`.** Protocols (`BiometricAuthentication`, `BiometricAuthenticationRequestor`, `BiometricAuthenticationDelegator`) are declared `AnyObject & Sendable`. Value types (`BiometricAuthenticationError`, `BiometricAuthenticationType`, `BiometricAuthenticationResult`, `BiometricAuthenticationPolicy`) conform to `Sendable` directly.
- **Callbacks are delivered on the main queue.** Both delegator methods (`authenticated()`, `authenticationFailed(with:)`, `authenticationRequestInProcess(didChange:to:)`) and the completion-handler form of `authenticate(_:completion:)` are dispatched via `DispatchQueue.main.async` — safe to drive UI from directly, no extra hop required.
- **Completion closures are `@Sendable`.** The `authenticate(_:completion:)` signature accepts `@escaping @Sendable (BiometricAuthenticationResult) -> Void`, so captures are checked by the compiler under strict concurrency.
- **`BiometricAuthManager` is `@unchecked Sendable`.** Its mutable state (`context`, `isAuthRequestInProcess`, `previousAuthenticationTime`) is mutated only from the LocalAuthentication callback and the call site that initiated authentication; the in-process guard (see below) prevents overlap.

## Thread Safety & Re-entrancy

`BiometricAuthManager` is **not** safe to drive concurrently from multiple tasks, but it is safe against accidental double-invocation:

- `isAuthRequestInProcess` is checked at the top of both `authenticate(_:)` overloads. A second call made while a prompt is already on screen is a **no-op** — it will not stack a second `LAContext` or trigger duplicate callbacks.
- State transitions on `isAuthRequestInProcess` are surfaced through `authenticationRequestInProcess(didChange:to:)` on the delegator, so the UI can disable the trigger button or show a spinner without racing the in-process flag.
- Treat each `BiometricAuthManager` instance as **single-flow**: drive it from one screen / one feature at a time. If you need parallel flows, instantiate one manager per flow.

## Error Mapping

All `LAError` codes are normalized into `BiometricAuthenticationError`, each with a `LocalizedError` description suitable for end-user display: `.failed`, `.canceledByUser`, `.fallback`, `.canceledBySystem`, `.passcodeNotSet`, `.biometryNotAvailable`, `.biometryNotEnrolled`, `.biometryLockedout`, `.other`.

## Testing

Because feature code depends only on `BiometricAuthInterface`, unit tests can substitute a fake conforming to `BiometricAuthentication`:

```swift
final class FakeBiometricAuth: BiometricAuthentication {
    // Drive any scenario from your test without touching LAContext
}
```

## Documentation

Full DocC documentation is available for every public type, protocol, and method. Build the documentation in Xcode via **Product → Build Documentation**, or generate it from the command line with `swift package generate-documentation`.

## License

See the repository for license details.
