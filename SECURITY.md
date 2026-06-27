# Security Policy

## Supported Versions

BiometricAuthKit follows semantic versioning. Security fixes are applied to:

| Version | Supported          |
| ------- | ------------------ |
| Latest `main` | Yes (active development) |
| Most recent tagged release | Yes (security patches) |
| Older releases | No (please upgrade) |

## Reporting a Vulnerability

**Do not file a public GitHub issue for a security vulnerability.** Biometric authentication is a security boundary, and public disclosure before a fix is available exposes downstream users.

Please report vulnerabilities **privately** via one of these channels:

1. **GitHub Private Vulnerability Reporting** (preferred) — open the repository's **Security** tab and select **Report a vulnerability**. This creates a private advisory only the maintainers can see.
2. **Email** — `92spatter.prose@icloud.com`. Use the subject line `[BiometricAuthKit Security]` and encrypt sensitive details if possible.

Please include:

- A clear description of the vulnerability and its impact.
- Steps to reproduce, ideally with a minimal proof-of-concept.
- The affected version(s) / commit SHA.
- Your assessment of severity (CVSS score if you have one).
- Your name / handle for credit in the advisory (or "anonymous" if preferred).

## What to Expect

- **Acknowledgement within 72 hours.** We confirm receipt and assign a maintainer to triage.
- **Initial assessment within 7 days.** We evaluate impact and start work on a fix if confirmed.
- **Coordinated disclosure.** We aim to release a patched version within 30 days of confirmation for high-severity issues, 90 days for lower severity. We coordinate the disclosure timeline with you.
- **Credit.** Reporters are credited in the published security advisory (unless you request anonymity).

## Out of Scope

The following are not considered vulnerabilities in BiometricAuthKit:

- Issues caused entirely by the consuming app's misconfiguration (e.g. missing `NSFaceIDUsageDescription`).
- Bugs in Apple's `LocalAuthentication` framework — report these to Apple via [Apple Security Bounty](https://security.apple.com/bounty/).
- Behavior of biometric hardware (sensor accuracy, anti-spoofing) — these are platform-level concerns.
- Side-channel attacks against Secure Enclave — out of scope for an SDK that delegates to `LAContext`.
- Theoretical issues with no demonstrable exploit path against this SDK's API.

## Scope of Concern

Vulnerabilities that *are* in scope and we want to hear about:

- API surface that allows bypassing the configured `BiometricAuthenticationPolicy`.
- Reuse-window logic that lets stale authentications succeed beyond their allowable duration.
- Race conditions in `BiometricAuthManager` that could result in callbacks firing for the wrong attempt.
- Sendable / `nonisolated(unsafe)` decisions that create data races exploitable to corrupt authentication state.
- Memory safety issues from `withLockUnchecked` or the `unsafeBitCast` in the lock abstraction.
- Documentation that misleads consumers into insecure usage patterns.

## Public Disclosure

After a fix ships:

- A GitHub Security Advisory is published with the CVE (if applicable).
- The release notes call out the security fix.
- The reporter is credited per the agreed-upon disclosure plan.

Thank you for helping keep BiometricAuthKit and its users safe.
