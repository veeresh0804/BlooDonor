# BlooDonor

Emergency blood-donor matching platform. Flutter app + Supabase backend
(Postgres + Auth + Edge Functions + Realtime) + Firebase Cloud Messaging
for push notifications.

## Convex redesign in progress

The owner has confirmed all existing data is disposable prototype data.
The replacement backend in `convex/` is being developed independently with
stricter ownership, private-field projections and server-controlled donation
updates. The Flutter app **still uses Supabase** until the Convex deployment,
+91 OTP provider and client integration are configured and tested. New backend
protections do not change the old Supabase deployment's permissions.

See [the current redesign plan](docs/convex-migration-plan.md) for scope,
platform requirements and remaining deployment decisions. No live project
has been reset or migrated as part of local development.

## Prerequisites

- Flutter SDK (^3.11.0)
- A Supabase project (throwaway for dev)
- Firebase project (only needed for push; the app runs without it)

## Setup

### 1. Environment file (required before building)

```sh
cp .env.example .env
# then fill in real values
```

`.env` is bundled into the app, so **only these two public values** may ever
go in it. Never put the service-role key there.

| Key                | Value                        |
| ------------------ | ---------------------------- |
| `SUPABASE_URL`     | Your Supabase project URL    |
| `SUPABASE_ANON_KEY`| Your Supabase anon (public) key |

A missing `.env`, or one still holding `your_*_here` placeholders, boots the
app in demo mode instead of crashing.

### 2. Firebase (push notifications only)

- Android: add `android/app/google-services.json` (the Gradle wiring applies
  the plugin only when that file exists, so the project builds without it —
  just without push).
- Optional: generate `firebase_options.dart` (`flutterfire configure`) and
  uncomment the two lines referencing it in `lib/main.dart`.
- Without Firebase, FCM init is skipped and the app otherwise works.

### 3. Supabase database

Apply the numbered migrations **in order**. They are authoritative:

```sh
supabase db push   # applies supabase/migrations/001–011 in order
```

Do NOT apply anything else: `supabase/consolidated_migration.sql` was a stale
squash of 001–008 and has been deleted. Applying it after 009 would downgrade
security (open RLS policies, unguarded `confirm_donation_complete`).

Migration 009 is authoritative for RLS — do not change its policies without
reviewing every caller.

### 4. Vault secrets (required for the matching triggers)

`handle_new_blood_request` (005) and `notify_request_resolved` (011) read
these from `vault.decrypted_secrets` at runtime. Create them once as an admin
(migration 010 warns if they are missing):

```sql
SELECT vault.create_secret('https://<project-ref>.supabase.co', 'SUPABASE_URL');
SELECT vault.create_secret('<service-role-key>', 'SUPABASE_SERVICE_ROLE_KEY');
```

`pg_net` (used for trigger-to-function HTTP calls) is enabled by migration
005. If pushes never fire, check in order: vault secrets → `pg_net` enabled →
function deployed → function secrets set (Postgres and function logs tell you
which).

### 5. Edge-function secrets and deploy

```sh
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
supabase secrets set SUPABASE_URL="https://<project-ref>.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
supabase functions deploy send-emergency-notification
supabase functions deploy send-override-notification
supabase functions deploy send-community-sos
supabase functions deploy send-resolved-notification
supabase functions deploy send-sms   # mock only, see below
```

`FCM_SERVICE_ACCOUNT_JSON` is the full Firebase service-account key JSON
(FCM HTTP v1; the legacy server key is retired and will not work).

### 6. Run

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Known limitations

- **Family SMS is not implemented.** `send-sms` returns fake success and no UI
  calls it (wiring removed deliberately). Wire Twilio before reconnecting it.
- **Donation certificates are not generated.** `generate-certificate` returns a
  placeholder URL and nothing routes to the certificate screen.
- **All hospitals share hardcoded coordinates** (Hyderabad centre), so radius
  matching is meaningless until real locations are captured.
- **`escalating` request status is never set** by any flow yet.
- **Community SOS broadcast works server-side**, but clients only receive it if
  subscribed to the `hyderabad_donors` FCM topic (done in `NotificationService`
  init); the SOS screen itself is not wired to submit leads.
- **Dedupe before unique constraints apply.** Migrations 009/011 add
  `UNIQUE(user_id)` on profile tables but skip (with notice) if duplicate rows
  exist. Merge duplicates, then re-run.
