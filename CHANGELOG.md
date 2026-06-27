# Changelog

All notable changes to **BiometricAuthKit** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Sections are grouped as:
**Added**, **Changed**, **Deprecated**, **Removed**, **Fixed**, **Security**.

## [Unreleased]

_No unreleased changes yet._

## [0.1.0] - 2026-06-27

Initial public release.

### Added

- **Core authentication API** via the `BiometricAuthentication` protocol and its concrete
  implementation `BiometricAuthManager`, wrapping Apple's `LocalAuthentication` framework for
  Face ID, Touch ID, and Optic ID.
- **Two-product layering**:
  - `BiometricAuthInterface` — protocols (`BiometricAuthentication`,
    `BiometricAuthenticationRequestor`, `BiometricAuthenticationDelegator`) and value types,
    with no dependency on `LocalAuthentication`.
  - `BiometricAuth` — the concrete `BiometricAuthManager` that drives `LAContext`.
- **Delegate-based and completion-handler APIs** — `authenticate(_:)` delivers results through
  the `BiometricAuthenticationDelegator`; `authenticate(_:completion:)` additionally delivers a
  `BiometricAuthenticationResult` to a closure.
- **Configurable reuse window** — `preferredAuthenticationAllowableReuseDuration()` honors a
  recent successful authentication without re-prompting the user.
- **Strongly-typed model**: `BiometricAuthenticationType` (`faceIdentification`,
  `touchIdentification`, `opticIdentification`, `none`), `BiometricAuthenticationError`,
  `BiometricAuthenticationResult`, and `BiometricAuthenticationPolicy` — all `Sendable`.
- **Optic ID support** (`BiometricAuthenticationType.opticIdentification(permitted:)`) for Apple
  Vision Pro, guarded by `if #available(iOS 17, macOS 14, *)` so the case is only ever produced
  on platforms that report `LABiometryType.opticID` at runtime.
- **Configurable callback queue** via `BiometricAuthenticationRequestor.preferredDelegateQueue`
  (defaults to `DispatchQueue.main`), letting consumers redirect delegator callbacks and
  completion handlers off the main thread.
- **`LAError` normalization** — every `LAError` code maps to a `BiometricAuthenticationError`
  case with a `LocalizedError` description suitable for end-user display.
- **Cancellation and invalidation** — `cancelAuthentication()` invalidates the in-flight
  `LAContext`; `invalidateRecentBiometricAuthenticationStamp()` forces fresh verification on the
  next attempt.
- **Full DocC documentation** on every public type, protocol, property, and method.
- **Test coverage** using the Swift Testing framework, including a `ConcurrencySafetyTests`
  suite (concurrent `authenticate(_:)`, `cancelAuthentication` / `invalidate` races, concurrent
  property reads, `Sendable` across `Task.detached`, concurrent completion-handler delivery) and
  a `DelegateQueueDispatchTests` suite verifying callbacks land on the requestor-supplied queue.

### Security

- Thread-safe by construction: all mutable state is serialized through a
  `ConcurrencySafeContainer` that selects the best locking primitive at runtime (`Mutex` on
  iOS 18+ / macOS 15+, `OSAllocatedUnfairLock` on iOS 16+ / macOS 13+, `NSLock` otherwise).
  Concurrent `authenticate(_:)` calls are race-free, `cancelAuthentication()` cannot race the
  `LAContext` evaluation, and `BiometricAuthManager` is fully checked `Sendable`.
- Documented security boundary: BiometricAuthKit mediates platform biometric authentication but
  does not implement cryptographic primitives. Vulnerabilities in `LAContext` itself are out of
  scope and should be reported to Apple Security. See [`SECURITY.md`](SECURITY.md).
- Licensed under MPL-2.0 — modifications to MPL-licensed files remain under MPL-2.0, ensuring
  security-relevant patches stay open-source even when bundled in proprietary applications.

---

## Release Tagging Guide

When cutting a release, rename the `## [Unreleased]` section to the new version with a date,
then start a fresh `## [Unreleased]` block above it.

Semantic versioning summary for this project:

- **MAJOR** — breaking change to the public API of `BiometricAuthInterface` or `BiometricAuth`
  (renamed types, removed methods, changed enum cases, changed protocol requirements without
  default implementations).
- **MINOR** — new public API, new enum cases, new protocol requirements with default
  implementations, new defaults, or behavior changes that are observable but source-compatible.
- **PATCH** — bug fixes, documentation updates, internal refactors, dependency bumps, and test
  additions.

[Unreleased]: https://github.com/kaVish2214/BiometricAuthKit/compare/0.1.0...HEAD
[0.1.0]: https://github.com/kaVish2214/BiometricAuthKit/releases/tag/0.1.0
