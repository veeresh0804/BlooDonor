# BlooDonor: Convex prototype redesign

Updated 28 October 2026. This plan supersedes the earlier data-preserving migration plan following the owner's clarification: all existing data is disposable prototype data, with no real donors or customers.

## Authorized scope

Build a fresh, more restrictive Convex schema and backend. Keep +91 phone OTP as a requirement, and Android, iOS, web and Windows as targets. Existing Supabase SQL remains a reference for the current app; no live project deletion or reset is needed to develop the replacement. Do not switch the app to an unconfigured backend.

This is a security-focused prototype, not a claim of perfect security or a completed production migration. Test authorization and business invariants independently of the UI. Type validation alone does not authorize access.

## Design requirements

- Identify users from validated authentication tokens, never from a caller-provided user ID or phone number.
- Require a verified +91 phone claim for onboarding. Keep role changes, hospital verification, donation totals, points, and cooldown changes out of general profile updates.
- Use explicit argument allowlists and minimal response projections. A hospital tracking a donor must not receive that donor's emergency contacts, authentication identifiers, device tokens or precise home coordinates.
- Scope every public query and mutation to its intended actor. Anonymous callers and unrelated accounts must fail. Avoid generic public CRUD functions.
- Keep request creation and donor matching server-side. Enforce one response per donor/request transactionally. A public donor endpoint must not accept a client-supplied compatible/matched flag.
- Enforce explicit transitions and closed-request checks on the server. Donation confirmation requires the owning hospital, an eligible response state and positive bounded units. Repeated confirmation must not credit another donation.
- Record donation facts once and derive or transactionally maintain aggregate counters. Keep an audit record of server-owned changes.
- Use separate device registrations for multiple devices. Tokens are private and only available to internal notification delivery code.
- Separate private donor contact/location data from the minimum data needed for matching and tracking.
- Store durable notification jobs with delivery state; external push attempts must not run inside the logical donation transaction. Do not describe a queued event as delivered.
- Keep strict blood group/Rh validation. Do not silently guess unknown blood types. Clinical compatibility and cooldown policy are not being newly validated by this coding work.

## Implementation and rollout order

1. Verify the installed Flutter toolchain; run dependency resolution, analysis and tests, fixing concrete errors.
2. Implement the Convex schema, ownership helpers and core request/response/confirmation functions with local tests. Keep this isolated from the running Supabase app until configured.
3. Independently review cross-account access, private-field exposure, state transitions, retries and duplicate confirmation. Fix reproducible findings and record test coverage.
4. Configure a Convex development project and choose an OTP identity provider. The project URL, issuer/audience configuration and provider credentials are still pending. Authentication must fail closed until configured.
5. Prove +91 OTP, token refresh, logout isolation, realtime reconnect and release builds on all four platforms. Integrate backend adapters into Flutter only against the validated contract.
6. Complete server-side matching and notification delivery, and exercise the full emergency loop with synthetic data. No real-data importer or legacy-ID mapping is needed.
7. Replace the prototype backend after end-to-end checks. Delete/reset an old hosted project only when explicitly selected for that action; schema redesign does not require deleting it now.

## Platform and service decisions still pending

| Area | Requirement before completion |
| --- | --- |
| Convex project | Development deployment and local authenticated CLI access |
| Phone login | +91 OTP provider with signed identity tokens, delivery/cost controls and desktop/browser support |
| Flutter client | Test a pinned community client for Android, iOS, web and Windows; HTTP success alone does not prove realtime behavior |
| Android push | Firebase configuration, channel and physical-device foreground/background/tap tests |
| iOS push | Apple build host/device, APNs credentials and capabilities |
| Web push | Service worker, web push configuration and browser permission tests |
| Windows push | Production delivery strategy; an open-app realtime subscription is not background push |
| Availability | Confirm Convex inactivity behavior and free-plan limits before treating it as a solution to automatic pausing |

## External documentation checked

- [Convex schemas](https://docs.convex.dev/database/schemas): typed document validators are available; application-level authorization remains necessary.
- [Convex OIDC authentication](https://docs.convex.dev/auth/advanced/custom-auth): configure issuer/audience and verified signed tokens. Do not implement a trust-by-phone shortcut.
- [Convex Flutter community client](https://pub.dev/packages/convex_flutter): candidate only; native Rust/platform tooling and web behavior must be tested.
- [Firebase Flutter support](https://firebase.google.com/docs/flutter/setup): Windows Cloud Messaging is not listed; Windows Firebase support is described as development-only.
- [Convex limits](https://docs.convex.dev/production/state/limits): Free has hard caps; no unconditional always-on guarantee was established in this review.

## Verification boundaries

Local unit tests and type checks do not establish that deployed authentication, SMS or push delivery works. Record actual commands and outcomes in the implementation report. No secrets belong in source, logs or Flutter asset files; use server-side configuration for privileged credentials.
