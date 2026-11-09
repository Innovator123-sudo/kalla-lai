# Kalla-Lai — Developer Documentation

> Developer-facing documentation for the Kalla-Lai two-sided work marketplace. These seven README files translate the product specification into implementation-oriented guidance.

## Product at a glance

Kalla-Lai connects independent service providers (workers) with employers and consumers who need work completed. The product supports two primary modes:

- **Vacancy mode:** workers create a professional profile, complete verification, discover nearby work, apply or respond to dispatches, coordinate shifts, and track payment status.
- **Hiring mode:** employers create job requisitions, review suitable workers, coordinate shifts, monitor attendance, review completion, and settle payment or raise a dispute.

The platform's core capabilities are identity and work-authorization checks, geospatial discovery, shift dispatch, worker profiles and portfolios, payment review/resolution, and trust/reputation features.

## Documentation map

| README | What it covers |
|---|---|
| [`architecture/README.md`](architecture/README.md) | System boundaries, components, target architecture, and technology choices |
| [`workflows/README.md`](workflows/README.md) | Worker, employer, verification, discovery, dispatch, shift, and payment flows |
| [`data-memory/README.md`](data-memory/README.md) | Persistent data, application state, Redis cache, storage boundaries, and retention |
| [`api-realtime/README.md`](api-realtime/README.md) | API domains, example contracts, WebSocket events, notifications, and integration rules |
| [`security-privacy/README.md`](security-privacy/README.md) | Threat model, authentication, authorization, privacy, payments, and security testing |
| [`uiux-quality/README.md`](uiux-quality/README.md) | Design system, key screens, accessibility, quality gates, and release readiness |

## Flutter client and API

The repository includes a Flutter client under `lib/` and a Node.js API under `server/`. The client supports email/password authentication, vacancy/hiring mode switching, discovery, job requisitions, worker profiles, and sample shift/payment flows. The API implements durable marketplace workflows, sessions, and role-based authorization. Demo data and payment/identity integrations remain clearly separated from real production providers.

To generate native host folders and resolve dependencies:

```powershell
flutter create --platforms=android,ios,web .
flutter pub get
```

The app opens with the supplied intro clip, displayed in a portrait 9:16 viewport with a center crop; users can skip it. The supplied source clip itself is landscape (1000×480) and has a visible watermark, so replace `assets/videos/output.mp4` with a licensed portrait 9:16 export before release if the crop or watermark is not acceptable. The supplied Kalla-Lai logo is packaged at `assets/images/kalla_lai_logo.png`.

The discovery screen uses a clearly labelled schematic map by default. To enable the Google Maps widget, configure the platform-specific Maps SDK keys outside source control, then run with `--dart-define=KALLALAI_MAPS_CONFIGURED=true`. Do not put keys in Dart source or commit platform secrets.

### Firebase Google sign-in setup

Google sign-in is implemented through Firebase Authentication on web and native Google sign-in on Android/iOS. The API verifies Firebase ID tokens with the Firebase Admin SDK before creating a Kalla-Lai session. A first-time Google user chooses a worker or employer role; an existing password account is not silently linked by matching email.

1. The web app is configured for the `kalla-lai` Firebase project, and Google is enabled under **Authentication → Sign-in method**. The Firebase web API key and app ID are public client configuration; restrict the API key to the APIs and web origins used by this app in Google Cloud if appropriate.
2. Register each Android application ID and its release/debug SHA-1 and SHA-256 fingerprints in Firebase. Register the iOS bundle ID and add the reversed iOS OAuth client ID URL scheme to the Runner target.
3. For local web development, start the API in one PowerShell window:

   ```powershell
   cd server
   $env:FIREBASE_PROJECT_ID = "kalla-lai"
   $env:PORT = "8090"
   gcloud auth application-default login
   npm run dev
   ```

   `gcloud` must be installed. Sign in with an account that has access to the Firebase project. In Firebase Authentication settings, make sure `localhost` is in the authorized domains list.
4. In a second PowerShell window, start the Flutter web app:

   ```powershell
   flutter run -d web-server --web-hostname localhost --web-port 7357
   ```

   Open `http://localhost:7357`. The web Firebase values are configured as defaults; override them with `--dart-define` when building for another Firebase project.
5. Android/iOS Google sign-in remains disabled until the corresponding Firebase app IDs, OAuth client IDs, Android signing fingerprints, and iOS URL scheme are configured. Never commit service-account JSON or private keys.

The API rejects Firebase sign-in if its project ID or verifier credentials are unavailable. Android/iOS folders must first be generated if they are absent.

Firebase Google sign-in does not make the entire product production-ready by itself. Payment-provider settlement, identity/KYC handling, push notifications, licensed font assets, production infrastructure, legal review, and full release testing still require their own configuration and validation. The UI must not claim a worker was verified, money moved, or a job published unless the corresponding authoritative service confirms it.

### Identity verification setup (Veriff)

The app uses Veriff's hosted session flow so Kalla-Lai does not capture or store identity images or face video. Veriff performs the configured document OCR, selfie/face comparison, and liveness checks. A user must explicitly consent, finish profile onboarding, and receive an `approved` decision through the signed server webhook before the marketplace home unlocks. A completed SDK/hosted session alone is not proof of approval.

1. Create a Veriff account and integration, enable document + selfie verification and liveness for the markets and documents you support, and review its privacy/data-collection requirements. See Veriff's [session creation](https://devdocs.veriff.com/docs/how-to-generate-sessions-manually.md), [decision webhook](https://devdocs.veriff.com/docs/decision-webhook.md), and [HMAC security](https://devdocs.veriff.com/docs/hmac-authentication-and-endpoint-security.md) guides. Configure the decision webhook URL as `https://<your-api-host>/v1/verification/veriff-webhook`.
2. Set `VERIFF_BASE_URL`, `VERIFF_API_KEY`, and `VERIFF_SHARED_SECRET` in the API's secret manager or local environment. Never put these credentials in Flutter defines or commit them.
3. Apply the database migration and deploy the API over HTTPS. The webhook validates Veriff's `X-HMAC-SIGNATURE` against the raw request body; the API stores only the session reference, consent version/time, and decision state—not document images, face templates, or OCR data.
4. Configure the mobile app's `KALLALAI_API_URL` to that HTTPS API. Run `npm run db:migrate` and `npm run dev` from `server/` for local development; a local-only, non-public API cannot receive Veriff webhooks.
5. Test the full flow in a Veriff test integration, including rejected, resubmission-requested, duplicate, malformed, and invalid-signature webhooks. Production use requires the provider agreement, applicable privacy notice/consent review, retention and deletion policies, account credentials, and public HTTPS hosting. Those cannot be created or legally approved in source code.

This integration is not active until Veriff credentials and its webhook are configured. Employer/worker profile setup collects an area/city rather than a private home street address. Profile-photo upload remains unavailable until private object storage and retention controls are configured.

## Supabase backend configuration

Supabase can be the system of record for the whole API. The supplied publishable key is already stored in `server/.env`:

```env
SUPABASE_PUBLISHABLE_KEY=sb_publishable_3ldEwOXQYjGA3KP0cGIrOw__A39TRCo
```

`sb_publishable_...` keys are short opaque strings, **not JWTs**, and they do **not** contain the project URL or reference id. They are sent on the `apikey` header (never as `Authorization: Bearer`) and are safe to expose to the Flutter client. These values come from the Supabase dashboard:

| Variable | Where to find it | Purpose |
|---|---|---|
| `SUPABASE_PROJECT_REF` | **Settings → General → Reference ID** (the 20 chars in `https://<ref>.supabase.co`) | Derives `SUPABASE_URL` and the `postgres.<ref>` pooler username |
| `SUPABASE_DB_HOST` | **Connect → Connection string → Transaction pooler → Host**, e.g. `aws-0-ap-south-1.pooler.supabase.com` | Builds the Postgres URL |
| `SUPABASE_DB_URL` | **Connect → Connection string** (full URI) | Alternative to the two parts above; takes priority |

`SUPABASE_DB_PASSWORD` is already set from the supplied credentials file. Quote it in `.env` if it contains `#`, `@` or `:`; the API percent-encodes it when assembling the URI, so a literal `#` cannot truncate the host. Connection strings that still contain template placeholders (`PROJECT_REF`, `POOLER_HOST`, `[YOUR-PASSWORD]`) are rejected with a clear `configurationWarning` instead of a cryptic DNS error — the API falls back to the local engine until they are replaced.

`SUPABASE_SECRET_KEY` (`sb_secret_...`) is optional and **server-only**; never ship it to the client. Never commit a real connection string, database password or secret key — in particular delete the plaintext `.env.txt` at the repository root once its password has been copied into `server/.env`.

### Setup

```powershell
cd server
# One-time only, from server/.env (already filled in for this project):
#   SUPABASE_PROJECT_REF, SUPABASE_DB_HOST, SUPABASE_DB_PASSWORD,
#   SUPABASE_PUBLISHABLE_KEY, SUPABASE_ADMIN_EMAIL, SUPABASE_ADMIN_PASSWORD
npm run supabase:check     # optional: verify the key against the project
npm run supabase:setup     # schema + RLS + admin account (idempotent)
```

**To run the app there is no `npm run dev` step.** Double-click `start-local.bat` at the repository root. It starts the API (`:8090`) and the built web app (`:7358`) only if they are not already running, and skips a second start otherwise. No terminal commands needed.

Sign in with the **ID** `novacane232` (or the full `SUPABASE_ADMIN_EMAIL` address) and the password from `SUPABASE_ADMIN_PASSWORD` in `server/.env`. Login accepts either a full email or the local part of the email as an ID. `supabase:setup` keeps exactly one admin: changing `SUPABASE_ADMIN_EMAIL` renames the existing one, changing `SUPABASE_ADMIN_PASSWORD` rotates its password and revokes old sessions. Credentials are never written to the README or the launcher.

`supabase:setup` applies `src/db/migrations/*.sql` (all marketplace tables), then `supabase/migrations/20261108000000_profiles_admin.sql` (Row Level Security and staff profile functions), then creates or repairs one `ADMIN` account. It is idempotent: re-running it only applies migrations not already recorded in `schema_migrations` / `supabase_migrations`. While the project ref and pooler host are empty the API keeps using its local PGlite engine, so development still works offline.

Runtime state is visible at `GET /v1/supabase/status` (public; the reachability probe is cached server-side for 30 s) and `POST /v1/supabase/verify` (staff only, forces a fresh check). The probe calls `/auth/v1/settings` with the publishable key on the `apikey` header: Supabase now requires a **secret** key for the `/rest/v1/` OpenAPI root, so that endpoint returns 401 even for a valid publishable key. `GET /v1/app/config` returns the client-safe `supabase.url` and `supabase.publishableKey` — the Flutter admin console reads these at runtime, so no key is hard-coded into the app bundle.

`test/setup.ts` clears all Supabase variables and `config.ts` additionally forces local mode under Vitest, so `npm test` can never seed demo rows into a live project even when `server/.env` holds real credentials. The first `supabase:setup` run prints the generated admin password **once**; save it and rotate it after signing in.

### Admin profile configuration for workers and hirers

Platform staff (`MODERATOR`, `BILLING_ADMIN`, `ADMIN`) open **Admin console** from the account menu in `MainShellScreen`. For **any** account they can:

- **Create** a worker profile or a hirer (employer) profile, even if the person has not onboarded — `POST /v1/admin/people/:id/profiles/{worker|employer}` (idempotent).
- **Edit** account fields, roles, and every field of both sheets — `PATCH /v1/admin/people/:id` with partial `user`, `workerProfile`, and `employerProfile` objects. Saving a section also creates a missing sheet.
- **Remove** either sheet — `DELETE /v1/admin/people/:id/profiles/{worker|employer}`.
- Search and filter the directory — `GET /v1/admin/people?q=&role=&limit=`.

Every write is wrapped in one transaction, recorded in `audit_events` (`admin.person.update`, `admin.profile.create`, `admin.profile.delete`) and produces an in-app notification for the affected user. The admin console shows whether it is editing **Supabase** or the **local engine**, so demo data is never mistaken for live records.

On Supabase, `supabase/migrations/20261108000000_profiles_admin.sql` additionally enables RLS on `users`, `user_roles`, `worker_profiles`, and `employer_profiles`. `public.is_staff(uid)` (SECURITY DEFINER) gates the policies so only staff can configure or edit another person's sheets; ordinary users can only touch their own. Password hashes, Firebase UIDs, and identity documents are never granted to `anon` or `authenticated`. The Express API connects as the table owner and remains the authoritative, audited write path. Staff RPCs (`admin_configure_worker_profile`, `admin_configure_employer_profile`, `admin_update_account`, `admin_remove_profile`) are available for a future Supabase-Auth client; they check the caller's staff role and must not be exposed to unauthenticated users.

## Source decisions and implementation status

The source product specification names Flutter/Dart, Bloc/Cubit, Clean Architecture, Node.js/Go services, Envoy, REST/GraphQL, WebSockets, PostgreSQL/PostGIS, Redis Geospatial, object storage, FCM, and SMS fallback. It also names candidate identity-verification libraries and payment providers.

This documentation separates three kinds of statements:

- **Specified:** directly stated in the product specification or its UI/UX and security addendum.
- **Recommended:** an engineering pattern added here to make the specification implementable and testable.
- **Decision required:** an unresolved product, legal, provider, or architecture choice that the team must confirm before production.

A named technology is not automatically selected, integrated, licensed, legally available, or production-ready. Validate provider availability, fees, Nepal-specific requirements, security posture, and operational capability before committing.

## Non-negotiable product principles

1. The backend is authoritative for verification, job eligibility, permissions, shift state, and payment state. Never trust a mobile client to make these decisions.
2. Store durable business records in PostgreSQL. Redis is a cache/ephemeral layer, not the authoritative record for money, identity, or job state.
3. Keep identity documents and other sensitive data separate from ordinary profile data, with narrower access and explicit retention rules.
4. Request location only when needed. Precise tracking is shift-scoped, disclosed, and controlled; workers should not be tracked while offline or outside an active shift.
5. Every important screen must have loading, empty, success, error, offline, and permission-denied behavior as applicable. A visible control must work.
6. Never claim the application is impossible to breach. Reduce risk through secure design, tests, monitoring, updates, and incident response.
7. Do not claim regulatory compliance until qualified local review and evidence-backed implementation are complete.

## Suggested implementation order

1. Confirm roles, job lifecycle, verification rules, cancellation rules, payment/escrow state transitions, and dispute policy.
2. Build the design system and clickable prototypes for the main worker and employer journeys.
3. Implement authentication, profiles, server-side authorization, and verification-case workflow.
4. Implement job posting, matching, applications/dispatch, and shift coordination.
5. Add payment-provider integration only after the legal, banking, merchant, and provider constraints are confirmed.
6. Add real-time updates, notification fallbacks, observability, and support tooling.
7. Complete accessibility, load, privacy, and independent security testing before launch.

## Important unresolved decisions

- Exact job application versus direct dispatch/offer behavior and how an employer selects a worker.
- Whether the first release is a modular backend or independently deployed microservices. The original architecture proposes microservices; the addendum recommends avoiding premature service splitting. Start with clear module boundaries and split only when justified.
- The precise precedence between employer approval, exit/geofence evidence, a 48-hour review period, escalation, dispute, and escrow release.
- Nepal-compatible payment provider, wallet/bank payout rails, escrow/holding-account legality, tax handling, and fee disclosure.
- Which government identity/right-to-work interfaces are actually available and authorized for integration.
- Data retention periods, lawful basis/consent language, biometric handling, and applicable local compliance obligations.

## Glossary

- **Worker:** person offering services and accepting work.
- **Employer/client:** person or organization posting work and paying for it.
- **Requisition/job:** a published work opportunity.
- **Shift:** a scheduled time-bounded assignment derived from a job.
- **Geofence:** a geographic boundary used for a location-dependent workflow.
- **Escrow/held funds:** money held through a legally and technically appropriate payment arrangement until defined release conditions are met. The precise arrangement requires legal/provider confirmation.
- **PII:** personally identifiable information.
- **RBAC:** role-based access control.
- **BOLA/IDOR:** authorization flaws that allow one user to access another user's object.
