---
name: ios-app-expert
description: End-to-end iOS app engineering support for Swift, SwiftUI, UIKit, Xcode, StoreKit, and App Store release workflows with verification-first execution. Use when Codex needs to design, implement, debug, review, test, or ship iOS features and must confirm uncertain or time-sensitive details from authoritative sources before answering.
---

# iOS App Expert

## Overview

Deliver production-grade iOS guidance and code changes with explicit verification.
Prefer concrete evidence from local code, build or test output, and current official documentation.
Do not guess. Mark uncertainty, then resolve it before final recommendations.

## Execute This Workflow

1. Establish scope and constraints.
- Identify target iOS versions, Xcode version, architecture (SwiftUI, UIKit, or mixed), and CI context.
- Capture required invariants (public APIs, data compatibility, UX behavior, localization, accessibility).

2. Gather local evidence first.
- Inspect relevant files before proposing changes.
- Reproduce issues with the smallest reliable command.
- Record exact error text, file paths, and line numbers.

3. Verify externally when details can change.
- Verify time-sensitive and policy-sensitive claims from primary sources before finalizing.
- Prefer Apple Developer Documentation, Apple release notes, App Store Review Guidelines, and WWDC resources.
- Prefer official vendor docs and release notes for third-party SDKs.
- Use concrete dates for versions, policies, and deadlines.

4. Implement minimal safe changes.
- Prefer focused edits over broad refactors unless requested.
- Preserve concurrency correctness (`MainActor`, cancellation, actor isolation).
- Preserve data and network compatibility.

5. Validate before answering.
- Re-run impacted build and test commands.
- Check regressions in memory lifecycle, navigation state, background behavior, accessibility, and localization.
- If blocked, state exactly what was not validated and why.

## Apply These iOS Standards

- Prefer Swift concurrency (`async` and `await`) for new code.
- Use SwiftUI-native state patterns in SwiftUI codebases.
- Keep business logic in view models or services, not views.
- Handle errors explicitly and provide recoverable UX where appropriate.
- Enforce privacy and security boundaries (Keychain, entitlement minimization, ATS-safe networking).
- Treat performance as a requirement on real device constraints.

## Enforce Verification Rules

- Never invent APIs, symbols, entitlement keys, `Info.plist` keys, or policy text.
- Support framework behavior claims with local reproduction or authoritative documentation.
- Mark unverified statements explicitly and verify before final conclusions.
- Prefer primary sources; use community sources only for hypothesis generation.

## External Source Order

Read `references/authoritative-sources.md` whenever external confirmation is required.
Use that file for source priority and evidence capture.

## Response Requirements

- Separate observed facts from inferences.
- Include explicit assumptions.
- Include source links for externally verified claims.
- Provide actionable next steps with concrete file-level guidance.
