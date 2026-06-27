# BiometricAuthKit

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)
[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2014%2B%20%7C%20macOS%2010.15%2B-blue.svg)](https://www.apple.com)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://www.swift.org/package-manager/)

A lightweight, protocol-oriented Swift package that wraps Apple's `LocalAuthentication` framework to make Face ID and Touch ID authentication simple, testable, and dependency-injection friendly on iOS and macOS.

## Purpose & Intent

The `LocalAuthentication` framework is powerful but low-level: callers have to manage `LAContext` lifecycles, translate `LAError` codes, marshal the framework's internal-queue callbacks onto whichever queue they actually want, and re-implement common ergonomics like "don't prompt again if the user authenticated five seconds ago" on every project.

**BiometricAuthKit** exists to solve that. It provides:

- A **clean public surface** (`BiometricAuthentication`) for performing biometric authentication, with both delegate-based and completion-handler APIs.
- A **separated interface module** (`BiometricAuthInterface`) so application code, tests, and mocks can depend on protocols and value types — never on the concrete `LocalAuthentication`-backed implementation.
- **Built-in reuse-window logic** so a previous successful authentication can be honored without re-prompting the user, configurable per request.
- **Strongly-typed errors and states** (`BiometricAuthenticationError`, `BiometricAuthenticationType`, `BiometricAuthenticationResult`, `BiometricAuthenticationPolicy`) that wrap the framework's `LAError` codes and policies into ergonomic Swift enums with `Sendable` conformance.
- **Swift 6 / strict concurrency** support — all public types are `Sendable`, and callbacks are delivered on the requestor's `preferredDelegateQueue` (defaulting to the main queue).

## Why two products?

The package ships **two libraries**:

| Product | Contents | Depend on it when… |
|---|---|---|
| `BiometricAuthInterface` | Protocols (`BiometricAuthentication`, `BiometricAuthenticationRequestor`, `BiometricAuthenticationDelegator`) and value types (errors, results, policies, types). | You are a feature module, app layer, or test target that only needs to *talk to* a biometric authenticator without pulling in `LocalAuthentication`. |
| `BiometricAuth` | The concrete `BiometricAuthManager` implementation that drives `LAContext`. | You are the composition root (app target, DI container) and need to instantiate the real authenticator. |

This split lets feature code stay decoupled from `LocalAuthentication`, makes mocking trivial in unit tests, and keeps build times for downstream modules small.

## Requirements

- iOS 14.0+ / macOS 10.15+
- Swift 6.3 toolchain (language mode `.v6`)
- Xcode 16+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kaVish2214/BiometricAuthKit.git", from: "0.1.0")
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
case .opticIdentification(let permitted):
    // Show a "Use Optic ID" affordance (Apple Vision Pro), disabled when !permitted
case .none:
    // Hide biometric UI entirely
}
```

> **Note:** `.opticIdentification` is only ever returned on iOS 17+ / macOS 14+ / visionOS 1+. On the package's minimum deployment targets (iOS 16 / macOS 13) the case is reachable in the type but the system will never produce it at runtime.

## Customizing the Callback Queue

By default, all delegator callbacks and completion handlers are delivered on `DispatchQueue.main`, so it's safe to drive UI directly. If the consumer maintains its own serial isolation queue, or wants to handle results off the main thread, override `preferredDelegateQueue` on the requestor:

```swift
final class BackgroundAuthRequestor: BiometricAuthenticationRequestor {
    private let queue = DispatchQueue(label: "auth.callbacks")

    var preferredDelegateQueue: DispatchQueue { queue }

    func preferredAuthenticationReason() -> String { "Unlock your account" }
}
```

Both delegator methods and the `authenticate(_:completion:)` completion closure will be dispatched on the queue returned by this property.

## Cancellation & Reuse

- `cancelAuthentication()` invalidates the in-flight `LAContext` and resets the in-process flag.
- `invalidateRecentBiometricAuthenticationStamp()` clears the cached success timestamp so the next `authenticate(_:)` call always prompts, regardless of the reuse duration.

## Concurrency Guarantees

BiometricAuthKit is designed for Swift 6 strict concurrency:

- **All public types are `Sendable`.** Protocols (`BiometricAuthentication`, `BiometricAuthenticationRequestor`, `BiometricAuthenticationDelegator`) are declared `AnyObject & Sendable`. Value types (`BiometricAuthenticationError`, `BiometricAuthenticationType`, `BiometricAuthenticationResult`, `BiometricAuthenticationPolicy`) conform to `Sendable` directly.
- **Callbacks are delivered on the requestor's `preferredDelegateQueue`** (defaults to `DispatchQueue.main`). Both delegator methods (`authenticated()`, `authenticationFailed(with:)`, `authenticationRequestInProcess(didChange:to:)`) and the completion-handler form of `authenticate(_:completion:)` are dispatched asynchronously on that queue — safe to drive UI from directly with the default, and easy to redirect off the main thread by overriding the requestor's property.
- **Completion closures are `@Sendable`.** The `authenticate(_:completion:)` signature accepts `@escaping @Sendable (BiometricAuthenticationResult) -> Void`, so captures are checked by the compiler under strict concurrency.
- **`BiometricAuthManager` is fully checked `Sendable`** (no `@unchecked` escape hatch on the type). Mutable instance state lives inside a `ConcurrencySafeContainer`, which selects the best locking primitive at runtime — `Mutex` on iOS 18+ / macOS 15+, `OSAllocatedUnfairLock` on iOS 16+ / macOS 13+, `NSLock` otherwise. The `requestor` and `delegator` are held as `weak let` (immutable, atomically zeroed by the runtime), so they're `Sendable`-safe without a lock. The only `withLockUnchecked` calls are at the lines that touch `LAContext`, because Apple has not marked `LAContext` as `Sendable`.

## Thread Safety & Re-entrancy

`BiometricAuthManager` is safe to drive from any thread or task:

- **Concurrent `authenticate(_:)` calls are race-free.** The "check whether a request is in progress" and "claim the slot" steps happen inside a single locked critical section. A second call made while a prompt is already on screen is a **no-op** — it will not stack a second `LAContext` or trigger duplicate callbacks.
- **`cancelAuthentication()` racing with the LA callback is safe.** The active `LAContext` is captured under the lock and invalidated outside it, so the framework's own evaluation cannot race with `invalidate()`.
- **State transitions on `isAuthRequestInProcess` are atomic** and surfaced through `authenticationRequestInProcess(didChange:to:)` on the delegator — the UI can disable the trigger button or show a spinner without racing the in-process flag.
- **Treat each `BiometricAuthManager` instance as single-flow at the product level.** Concurrent callers are *serialized* (the second is silently rejected), not parallelized. If you need genuinely parallel authentication flows (rare), instantiate one manager per flow.

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

BiometricAuthKit is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See the [`LICENSE`](LICENSE) file for the full text.

Copyright (c) 2026 kaVi Gevariya ([@kaVish2214](https://github.com/kaVish2214)).

In short, MPL-2.0 is a weak-copyleft license:
- You may use, modify, and distribute this software in commercial and proprietary projects.
- Modifications to files originally licensed under MPL-2.0 must remain under MPL-2.0 and be made available under the same terms.
- The license is file-based — combining this code with proprietary code in a Larger Work is permitted, provided the MPL-licensed files themselves remain under MPL-2.0.

For the official SPDX identifier and the canonical license URL: `SPDX-License-Identifier: MPL-2.0` — https://mozilla.org/MPL/2.0/.
