# Security Policy

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.** Public disclosure before a fix can put users at risk.

Use GitHub's private reporting channel: **Security → Report a vulnerability** in the [repository](https://github.com/Innovator123-sudo/kalla-lai/security/advisories/new), or contact the maintainers through the [website's contact page](https://innovator123-sudo.github.io/kalla-lai/contact.html) asking for a private channel.

Include, if you can:
- The affected component (`lib/`, `server/`, `site/`, deployment config)
- Steps to reproduce and the impact
- Any suggested fix
- Whether the issue is already public

**[FOUNDER INPUT: add a dedicated security@ email once a domain and inbox exist.]**

## What we ask of you

- Give us reasonable time to investigate and fix before disclosure.
- Do not access, modify or exfiltrate data you do not own.
- Do not run destructive tests against the live deployment or the live database.
- Use a test account and a local environment.

## Scope

In scope: the Flutter client, the Node/TypeScript API, authentication and session handling, verification webhooks, marketplace state transitions, the ledger model, database access controls, and the public website.

Out of scope: issues in third-party providers (report those to the provider), social engineering of maintainers, denial-of-service from volumetric traffic, and findings that require a compromised user device.

## Security design commitments

- Identity verification decisions are accepted only through HMAC-signed provider webhooks; a completed SDK session alone is never treated as approval.
- The platform stores no identity-document images, face templates or OCR payloads.
- Role-based authorization on every marketplace route, idempotency on state changes, structured validation and rate limiting.
- Access tokens are short-lived with rotating refresh sessions; signing and webhook secrets stay server-side.
- The UI never shows "verified", "paid" or "published" without an authoritative confirmation.

See [`security-privacy/README.md`](security-privacy/README.md) for the full threat model and [`startup/LEGAL-CHECKLIST.md`](startup/LEGAL-CHECKLIST.md) for the pre-launch security gates.

## Known deployment caveats

The currently published demo deployment runs with `DEMO_MODE=true` / `NODE_ENV=development` to match local behaviour, which means Firebase ID tokens are not fully signature-verified there. **This must be changed before real users.** See the [startup checklist](startup/README.md#founder-setup-checklist) for the production-secrets gate.

Never commit `.env` files, service-account JSON, private keys or database passwords. If you find a credential in the repository, report it privately and rotate it immediately.
