# Kalla-Lai Project Memory

## Tech Stack
- **Frontend**: Flutter (Dart), Bloc pattern (AuthCubit, ProfileCubit, AdminCubit, HiringRequisitionCubit)
- **Backend**: Express + TypeScript, PGlite fallback / Supabase Postgres
- **DB**: Live Supabase (ref: rbviukwjttcommuodnlh, pooler: aws-0-ap-northeast-1)
- **Admin login**: email=`novacane232` (or `novacane232@kallalai.app`), password=`[redacted]`
- **Server**: runs on port 8090 via `start-local.bat` (no `npm run dev` needed)
- **Flutter SDK**: 3.47.9, not on PATH in shell — use full path or IDE

## Key Architecture
- Profiles route at `/v1/workers/me` and `/v1/employers/me` (PATCH)
- Staff (ADMIN/MODERATOR/BILLING_ADMIN) can edit both worker and employer profiles
- Admin route at `/v1/admin/people/:id/profiles/{worker|employer}` for staff to create/edit profiles
- Uploads support IMAGE, CV, PROMO_VIDEO kinds
- Migrations auto-apply on server startup (schema_migrations table)

## Employer Profile (enriched Nov 2026)
- Migration `010_employer_profile_rich.sql` added: profile_picture_url, bio, tagline, base_area, latitude, longitude, contact_phone, website_url, categories[], languages[], portfolio_urls[]
- Flutter `EmployerProfile` model and `_EmployerProfileEditor` widget rebuilt with full customization
- Hiring wizard (`hiring_requisition_cubit.dart`) has `companyInfo` field for "About your company" in step 1

## Server Config
- `.env` has live Supabase credentials (DB password with `#`, stored as SUPABASE_DB_PASSWORD)
- `config.ts` assembles DB URL from parts with percent-encoding
- `runningUnderTest` guard prevents tests from writing to live Supabase
