# Contributing to BiometricAuthKit

Thanks for considering a contribution. This document covers how to propose changes, the licensing terms your contribution will fall under, and a few project-specific conventions.

## Licensing of Contributions

BiometricAuthKit is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. By submitting a pull request, you agree that **your contribution is licensed under MPL-2.0** under the same terms as the rest of the project ("inbound = outbound").

You retain copyright in your contribution. You do not need to sign a separate Contributor License Agreement (CLA) — the act of submitting the PR is itself the license grant.

If your contribution includes code copied or derived from another project, you **must**:

1. Verify that the source license is compatible with MPL-2.0 (e.g. MIT, BSD, Apache-2.0 with attribution, or MPL-2.0 itself).
2. Preserve the original copyright notice in the file.
3. Update the file's `Copyright (c)` line to include both the original author and any new attribution.
4. Mention the borrowed code and its source license in your PR description.

GPL/AGPL/LGPL code is **not** accepted — MPL-2.0 is "weak copyleft" by file, and pulling in stronger copyleft would relicense large parts of the project.

## Reporting Bugs

Open an issue with:

- A short, descriptive title.
- Steps to reproduce (a minimal Xcode project or test case is ideal).
- Expected vs. actual behavior.
- The Swift version, Xcode version, and target OS (iOS / macOS version).
- If applicable, the `LAError` code or wrapped `BiometricAuthenticationError` case you observed.

**Security vulnerabilities should not be reported as public issues.** See [`SECURITY.md`](SECURITY.md) for the private disclosure channel.

## Proposing Features

Open an issue first to discuss the design before opening a PR. For a biometric authentication SDK, API surface changes carry compatibility weight — alignment up-front saves rework. Include:

- The use case driving the request.
- Sketch of the proposed API.
- Any breaking-change implications.

## Submitting Pull Requests

1. **Fork and branch** off `main`. Use a descriptive branch name (`feature/optic-id-support`, `fix/cancel-race`, etc.).
2. **Add a license header** to any new Swift file you create. Use the template below.
3. **Write tests** — the project uses the Swift Testing framework (`@Suite`, `@Test`, `#expect`). Any behavior change needs at least one test; concurrency-affecting changes need stress tests under `Tests/BiometricAuthKitTests/`.
4. **Keep the public API surface intentional** — the `BiometricAuthInterface` module is the contract every downstream consumer depends on. Changes there are breaking.
5. **Build clean and all tests pass** before opening the PR.
6. **Write a focused PR description**:
   - What changed and why.
   - Any behavior-visible differences.
   - Link to the discussion issue if there was one.

## Code Style

- 4-space indentation.
- `PascalCase` for types, `camelCase` for properties and methods.
- Use `let` when not mutating; reach for `var` only when needed.
- Prefer protocol-oriented design — feature modules should depend on `BiometricAuthInterface`, not `BiometricAuth`.
- Avoid Combine; use Swift's `async`/`await` for asynchronous work.
- DocC comments on every public type, property, and method.
- No emojis in code, comments, commit messages, or PR descriptions.

## License Header Template

Every new Swift file must start with:

```swift
//
//  FileName.swift
//  BiometricAuthKit
//
//  Copyright (c) <YEAR> <YOUR NAME>. All rights reserved.
//
//  SPDX-License-Identifier: MPL-2.0
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
```

Replace `<YEAR>` and `<YOUR NAME>` with your contribution details. If you're modifying an existing file substantially, you may add your name on a second `Copyright (c)` line below the original — do not remove existing copyright notices.

## Concurrency Conventions

BiometricAuthKit uses Swift 6 strict concurrency. When working on internals:

- All public types must be `Sendable` (or have a documented reason not to be).
- Mutable state must be inside the `state: ConcurrencySafeContainer` — never add stored mutable properties to `BiometricAuthManager` directly without lock protection.
- Never call out to user-supplied code (`requestor.*`, `delegator.*`) while holding the lock — snapshot what you need inside `withLock`, then call out after the closure returns.
- Callbacks are delivered on the `requestor.preferredDelegateQueue` (defaults to main). Do not change this without a deliberate API decision.

See the README's "Concurrency Guarantees" and "Thread Safety & Re-entrancy" sections for the broader contract callers depend on.

## Questions

Open a GitHub Discussion or an issue tagged `question`. For private matters (security, licensing questions on borrowed code), see [`SECURITY.md`](SECURITY.md) for contact.
