# Contributing to Kalla-Lai

Thanks for wanting to help. Kalla-Lai is an early-stage, product-first project — good contributions are ones that make the trust layer more correct, more honest or easier to operate.

## Before you start

- Read the [product overview](README.md) and the [startup playbook](startup/STARTUP-PLAYBOOK.md) for the principles behind the product.
- Skim the relevant domain doc: [architecture](architecture/README.md), [workflows](workflows/README.md), [data](data-memory/README.md), [API](api-realtime/README.md), [security](security-privacy/README.md) or [UI/UX](uiux-quality/README.md).
- For anything non-trivial, open an issue first so we agree on the approach.

## The rule that overrides everything

**The UI must never claim a worker was verified, money moved, or a job was published unless the corresponding authoritative service confirms it.** If your change touches verification, payments, shifts or reputation, add a test that protects this invariant.

## Development setup

```powershell
# Flutter client (Flutter 3.47.9)
flutter create --platforms=android,ios,web .
flutter pub get

# Or simply double-click start-local.bat for the local API (:8090) + web app (:7358)
```

The API lives in `server/`. See [README.md](README.md) for Supabase, Firebase and Veriff configuration. Build the public website with:

```powershell
python tools/build_site.py
```

## Making a change

1. Create a branch from `master`.
2. Keep changes focused. One concern per pull request.
3. Add or update tests for behavioural changes.
4. Run the checks that apply to your change:
   - `flutter analyze` and `flutter test`
   - `npm test` / `npm run build` inside `server/`
   - open the generated site at desktop and 390 px widths
5. Update documentation when behaviour changes — especially the [roadmap](https://innovator123-sudo.github.io/kalla-lai/roadmap.html) and [trust page](https://innovator123-sudo.github.io/kalla-lai/trust.html) if a capability becomes live.
6. Open a pull request using the template and describe **how you verified it**.

## Code conventions

- **Dart:** follow `analysis_options.yaml`; keep Cubits free of widget code; use the existing theme tokens rather than hardcoded colours.
- **TypeScript:** strict mode, structured errors, permission checks on every route, idempotency on state changes.
- **SQL:** additive, versioned migrations in `server/src/db/migrations/`; never edit an applied migration.
- **Website:** edit `tools/build_site.py`, never the generated `site/*.html` files directly.
- **Never commit** `.env`, service-account JSON, private keys, database passwords, provider secrets or real user data. See [SECURITY.md](SECURITY.md).

## Commit messages

Short imperative summary, then detail if needed. Examples:

```
Add signed webhook verification for KYC decisions
Fix intro advancing before first frame on slow connections
Document settlement states in the privacy notice
```

## Reporting bugs and vulnerabilities

- Bugs and feature ideas: [GitHub Issues](https://github.com/Innovator123-sudo/kalla-lai/issues).
- **Security vulnerabilities: do not open a public issue.** Follow [SECURITY.md](SECURITY.md).

## Community

Be respectful and constructive. Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Licensing

This repository currently has **no LICENSE file**, which means default all-rights-reserved applies. The licensing decision is tracked in the [startup kit checklist](startup/README.md#founder-setup-checklist). Please confirm before reusing any material in another project.
