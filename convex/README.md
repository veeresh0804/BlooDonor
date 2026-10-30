# Convex prototype backend

This is a new backend for disposable prototype data. Deployed on 29 October 2026
to the development deployment `moonlit-mouse-599` in `ap-southeast-2`.
Flutter still uses Supabase. No existing SQL policy is modified.

Verification: deployment succeeded, TypeScript check and 11 local tests passed,
and a live unauthenticated `dashboard:profile` request returned `Not authorized`.
Clerk development application `app_3LLkdhXJQHjW0tJ4Bvq7l4wGbN8` is now linked.
The `convex` JWT template includes `aud`, `phone_number` and
`phone_number_verified`, and the deployed backend trusts its Clerk issuer.
Authenticated live flows, OTP delivery and push delivery remain unverified.

## Run locally

From the repository root:

```powershell
npm ci
npm run backend:typecheck
npm run backend:test
```

The tests use `convex-test` with registered modules and injected identities. They
exercise backend validators/authorization and transactions in a mock backend;
they do not verify production JWTs, concurrent deployment behavior, OTP or push.
`server.ts` supplies schema-typed Convex bindings without requiring generated
deployment files. Use the normal Convex CLI initialization/codegen workflow after
the development project is supplied.

## Implemented boundary

- Verified +91 phone claims are required for onboarding. Each identity and phone
  has one account, enforced inside a mutation. Role is selected once; subsequent
  role changes are rejected. No phone-based automatic account takeover/linking.
- Hospital self-registration does not grant verification. `verifyHospital` is an
  internal function for trusted administration. Profile identity/location edits
  revoke verification. Only verified hospitals create requests and confirm new
  donations.
- Donors can edit availability/location, not points/cooldown or blood type after
  setup. Accounts expose no generic patch endpoint. Profile text is bounded.
- Requests snapshot hospital name/address/location. Matching is server-side,
  standard ABO/Rh compatibility with the existing eligible-donor rules, range
  checks and date-derived cooldown. This is an application matching filter,
  not medical clearance or a replacement for clinical screening.
- Each request's response records are created exactly once in its creation
  transaction, not by the donor. Donors may transition only their own match
  through explicit permitted states; they cannot mark themselves donated.
- One active accepted journey per donor. Confirmation requires arrival and a
  recorded health check, then atomically records the donation, points, cooldown,
  fulfilled units and closure. A per-response donation record protects retries;
  a repeated confirmation with different values is rejected. A donor's cooldown
  also blocks a second confirmation on another request.
- Request reads require ownership or a match. Tracker returns only status,
  blood group/Rh and journey timestamps; no name, phone, donor location or token.
- Device registrations belong to authenticated users and cannot be listed by
  clients. Revoke the registration before signing out/switching accounts.
- Notifications create internal pending outbox records containing only event,
  request and recipient IDs, never patient stories or contact details.

## Deployment and identity setup still required

### Create the development project

1. Sign in at https://dashboard.convex.dev and create a development project for
   BlooDonor. Share the development deployment URL when ready, not a deploy key.
2. From this repository, run `npx convex dev` in your own terminal. Complete the
   login/project selection prompts and select that development project. This
   command syncs backend code; keep production separate.
3. Select the +91 OTP provider and configure the issuer/audience below before
   expecting app users to authenticate. An empty provider list is deliberate.
4. Keep privileged credentials in backend configuration. Convex CLI local
   configuration is ignored by Git; do not copy it into Flutter's `.env` asset.

Flutter is not yet wired to these endpoints. Creating a project alone will not
switch the app or make OTP/push work.

The development project is linked locally. `auth.config.ts` trusts
`AUTH_ISSUER` with the fixed audience `convex`. This deployment's issuer is
`https://bright-sponge-4368.clerk.accounts.dev`. Convex requires the issuer
environment variable to exist at deployment time. Never use placeholder
issuers or an auth bypass. Flutter must request Clerk's `convex` JWT template,
not pass its ordinary session token without the expected audience/phone claims.

The identity provider must issue `phone_number` and `phone_number_verified`
claims, exposed by Convex as `phoneNumber` and `phoneNumberVerified`. Test actual
claim mapping, issuer, audience, signature/expiry validation, refresh, logout,
recovery and +91 SMS delivery during Flutter integration. Live OTP and
SMS delivery have not been tested yet. Phone-code login is enabled in Clerk;
email/password/username are no longer all required to register. Development
test-mode behavior does not establish real +91 SMS delivery. Configuration
payloads are recorded in `config/clerk/`; they contain no private keys.

## Explicit prototype limits and unfinished work

- Matching allows at most 100 available candidates; greater counts reject the
  request instead of silently truncating matches. Per-donor acceptance history
  is scanned to prevent multiple journeys. Add indexed active-journey tracking
  and paginated matching before scaling; this is not a high-volume backend.
- No outbox worker, FCM sends, retries, delivery metrics or scheduling yet.
  `pending` means queued in the database, never delivered. No notification UI
  should claim successful delivery. Native Windows push requires separate work.
- No cooldown override path: donors in cooldown are excluded and cannot bypass
  it. The existing interval constants are carried forward for prototype parity;
  clinical policy must be reviewed before real use.
- Ratings, referrals, certificates/rendering, NGO/camp workflows, community SOS,
  achievements UI, administration UI and audit log are not implemented. Dormant
  legacy tables are intentionally not exposed as generic public tables.
- Dashboard queries now expose own profile, paginated hospital requests, donor
  matches, and donation history (`dashboard:profile`, `hospitalRequests`,
  `donorRequests`, `donationHistory`). List queries require `limit` (1–50) and
  `cursor` (null initially, then the returned cursor). They derive the owner
  from authentication and accept no user/owner IDs. Private phone/auth/device
  fields are omitted. Flutter DTO adapters and subscription wiring remain work.
- Rate limiting, account recovery, token ownership attestation, abuse controls,
  retention/deletion and operational monitoring need work before real users.
- No live security guarantees or claim of being “leak-proof.” Additional
  production authorization, platform, credential and concurrency tests are needed.

References used: [Convex mutations](https://docs.convex.dev/functions/mutation-functions),
[auth in functions](https://docs.convex.dev/auth/functions-auth),
[Convex test runner](https://docs.convex.dev/testing/convex-test).
