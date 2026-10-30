# Convex prototype security review

28 October 2026. Scope: local schema and functions for a fresh prototype dataset. The owner confirmed there are no real donors/customers and authorized redesign. This review does not certify a deployed service or promise that data cannot leak.

## Required invariants

1. Every public query/mutation requires a verified identity. Application ownership comes from issuer/subject identity mapping, never a supplied user ID. Phone claims must be verified and match the India-only contract before account creation.
2. Role is fixed after onboarding. Creating a hospital account does not verify that hospital. Verification is a server/admin operation; prototype convenience must not introduce a public verification bypass.
3. Explicit mutation arguments allow only editable fields. No public generic table insert, patch, delete, role update, point update, cooldown update or confirmation-status update.
4. Only server matching creates donor/request relationships. Knowing a request ID does not authorize reading it or joining it. Donors see their matched requests; hospitals see their own requests and response projections.
5. Hospital tracker projections exclude donor phone, emergency contact, exact donor location, auth identifiers, and device tokens. A donor's own profile can contain their own private fields. Patient details must not be exposed in public lists, logs, push payloads or lock-screen text.
6. Public queries must build explicit projections rather than return entire user/profile documents. Authorization failure must not reveal whether another user's record exists.
7. Response pair uniqueness is enforced transactionally, not assumed from an ordinary index. Required references must resolve. Units, coordinates and radius need numeric bounds; blood group and Rh remain strict enums.
8. Donor transitions use an explicit transition graph. Donors cannot set donated, edit timestamps, reset completed responses or progress closed requests. Repeated requests must not reset historical timestamps.
9. Hospital confirmation requires ownership, an eligible response state, positive integral units and active request status. One response produces at most one donation event. Exact retry returns the existing result without further credits; retry with changed payload is rejected. The idempotency check must still work after the first call fulfils the request.
10. Units, points, cooldown and completed state change in one transaction. No client-supplied point totals. Counter updates and duplicate confirmations need concurrent-call testing.
11. Device tokens are private per-device records. Registration binds to the authenticated user. Logout/reassignment must not leave an old account receiving private notifications. A user must not claim another account's token without an explicitly designed ownership-transfer mechanism.
12. Matching, verification, outbox delivery, cleanup and bootstrap functions are internal. Scheduler functions recheck closed-request state, use bounded batches and record failures. Push is at-least-once at best: deduplicate where possible, never claim exactly-once external delivery.

## Acceptance tests

Use anonymous, donor A/B, hospital A/B, and unverified hospital identities. Test successful operations plus denied cross-account access, forged owner IDs, extra sensitive arguments, invalid blood types, duplicate relationships, invalid status transitions, closed requests, repeated/changed confirmation payloads and simultaneous confirmations. Assert returned objects omit private fields; absence of a UI button is not access control.

Test stale tokens and account switching separately from database tests. Test that internal functions are not exposed through public HTTP/API routing. A local function-test harness does not establish deployed authentication, transport security, push delivery, rate limits or all-platform support.

## Release conditions outside schema

- Select/configure a production-compatible +91 OTP provider and validate verified-phone claims, issuer and audience. Do not enable permissive production auth to make tests pass.
- Apply per-identity abuse limits to expensive create/match/OTP work; cap result sizes and resource use.
- Confirm production push support for each platform, especially Windows; realtime while open is not background push.
- Redact sensitive fields from application logs and provider errors. Store server credentials only in server environment variables.
- Confirm current Convex inactivity and quota behavior with the provider; migration alone does not guarantee availability.
- Keep the old Supabase application clearly identified until Flutter is actually switched and end-to-end tested. New Convex protections do not retrofit the old backend.

## Implementation review (29 October 2026)

Reviewed `convex/schema.ts`, `access.ts`, `auth.config.ts`, `profiles.ts`, `requests.ts`, `devices.ts`, and typed function builders in `server.ts` while implementation was in progress.

The core implements identity-derived ownership, verified +91 onboarding, immutable roles, internal-only hospital verification, explicit profile field allowlists, strict blood type validators, hospital location snapshots on requests, private tracker projections, guarded response transitions and transactional donation recording. Confirmation looks up an existing donation before enforcing the active-request check, so an exact retry after fulfilment can return the original result. Changed confirmation payloads are rejected. Device registration and revocation check account ownership. Default empty auth configuration does not intentionally admit test identities.

Requested one correction: `updateResponse` must verify the donor's matching response before returning request existence/status errors. Without this ordering, an unmatched caller can distinguish active requests from closed/missing requests. Backend agent is handling this change.

The schema is a deliberately smaller core, not a drop-in replacement for the existing Flutter backend. Ratings, leads, certificates, NGO features, cooldown override, request escalation and some profile fields are not implemented in this core. Patient stories/emergency contacts are not stored, which reduces exposure but changes feature scope. Flutter remains on Supabase until integration. Core protections therefore do not change the running Supabase app.

Matching is bounded to at most 100 available donor candidates and fails above that limit rather than silently skipping matches. There is no notification delivery worker: outbox records remain pending. No HTTP routes or public wrappers expose internal verification. Provider configuration, real OTP, deployment behavior, resource abuse limits, Windows notifications and end-to-end authorization remain release work. This is a source-level review; test results should be taken from the backend agent's actual command output, not inferred from this report.
