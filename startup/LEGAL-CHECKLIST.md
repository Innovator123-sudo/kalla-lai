# Kalla-Lai — Legal & Compliance Checklist

> **Not legal advice.** This is a working checklist for an early-stage marketplace, written to make the open items visible. Every item needs review by qualified counsel in the launch jurisdiction. Do not launch real payments, KYC or user data collection until the relevant gates below are signed off.

---

## Launch gates (hard blockers)

These must all be **done** before the service accepts real users with real money or real identity data:

- [ ] Legal entity registered, tax ID, business bank account **[FOUNDER INPUT]**
- [ ] Counsel-reviewed Privacy Notice and Terms of Service published (remove the draft banners in `site/privacy.html` and `site/terms.html`)
- [ ] Data controller / processor roles documented, with a named contact and DPO or privacy lead where required **[FOUNDER INPUT]**
- [ ] Signed agreement with a licensed payment provider; settlement confirmed only by signed webhooks
- [ ] KYC provider agreement, consent wording and retention/deletion policy approved for the launch market
- [ ] Production secrets rotated and moved to a secret manager; `DEMO_MODE=false`; CORS restricted to production origins
- [ ] Worker classification / labour-law opinion obtained for the launch jurisdiction
- [ ] Incident response and breach notification plan documented, with an owner

---

## 1. Corporate & governance

| Item | Status |
| --- | --- |
| Entity type and registration | **[FOUNDER INPUT]** |
| Founders' agreement, equity split, vesting | **[FOUNDER INPUT]** |
| IP assignment from all contributors | **[FOUNDER INPUT]** |
| Repository licence decision (currently no `LICENSE` = all rights reserved) | **[FOUNDER INPUT]** |
| Board / advisor structure | **[FOUNDER INPUT]** |
| Accounting, bookkeeping, tax filings | **[FOUNDER INPUT]** |
| Insurance: professional indemnity, cyber, general liability | **[FOUNDER INPUT]** |

## 2. Marketplace & labour law

- [ ] Determine whether workers are independent contractors, employees, or something else under local law. This changes tax, benefits, minimum wage and liability.
- [ ] Terms must state that Kalla-Lai provides a marketplace and record-keeping layer, and is **not** the employer (only if counsel confirms this is accurate).
- [ ] Verify rules on service fees / commission caps, worker payment deadlines and wage deductions.
- [ ] Check licensing requirements for employment agencies / staffing intermediaries.
- [ ] Review background-check and identity-verification legality, including what may be shown to employers.
- [ ] Define who is liable for workplace injury, property damage and third-party claims; consider insurance or a guarantee product.
- [ ] Complaint handling and escalation obligations, including any consumer-protection rules.

## 3. Privacy & data protection

- [ ] Map every personal data field: purpose, legal basis, retention, recipients, cross-border transfers.
- [ ] Publish a privacy notice that names the controller, contact details, rights and retention periods.
- [ ] Explicit, versioned consent for identity verification; log consent version and timestamp (already modelled in the API).
- [ ] Data-processing agreement with the KYC provider; confirm where data is processed and stored.
- [ ] Confirm the platform truly stores no document images, face templates or OCR payloads.
- [ ] Implement subject access, correction, deletion and export workflows.
- [ ] Define and implement retention/deletion schedules for chat, shifts, ledger entries and profile media.
- [ ] Private object storage with access controls and retention for profile photos, CVs and promo videos.
- [ ] Breach detection, logging and notification procedure with statutory timelines.
- [ ] Age eligibility and child-labour safeguards where relevant to the categories launched.

## 4. Payments

- [ ] Payment provider licence covers the launch market and the flow (marketplace / split settlement).
- [ ] KYC/AML obligations for the platform and for payees; understand who owns them.
- [ ] Escrow or safeguarded-funds rules — do not describe the ledger as escrow legally until confirmed.
- [ ] Signed webhooks only; idempotent settlement handling; reconciliation and audit trail.
- [ ] Refund, chargeback, failed-payout and dispute policies written and reflected in the UI.
- [ ] Fee disclosure: exact amount shown to both sides before they agree to a shift.
- [ ] Tax invoicing, reporting and record retention.

## 5. Product & consumer protection

- [ ] The "never claim what the system hasn't confirmed" invariant is enforced in tests (see [METRICS.md §5](METRICS.md#5-trust--safety-metrics)).
- [ ] Terms of the shift (scope, time, rate, location, cancellation) visible to both sides before agreement.
- [ ] Clear cancellation and no-show policy.
- [ ] Accessible dispute process with defined SLAs and escalation to a human.
- [ ] Ratings/reputation: disclose how they are computed, allow contesting, prevent retaliation patterns.
- [ ] Advertising and marketing claims reviewed — no unverified "trusted by", "instant payment" or "guaranteed" language.
- [ ] Accessibility and local-language review (नेपाली).

## 6. Security

- [ ] Rotate all JWT, webhook and session secrets; remove any credentials from tracked files.
- [ ] Secrets in a manager, never in `.env` committed to git or in Flutter `--dart-define` values.
- [ ] CORS allow-list limited to production origins.
- [ ] Rate limiting, idempotency, input validation, role-based authorization on every route.
- [ ] Supabase Row Level Security reviewed; service-role keys server-only.
- [ ] Firebase web API key restricted to the production origins and required APIs.
- [ ] Dependency scanning, secret scanning and a patching cadence.
- [ ] Penetration test before production launch; fix critical/high findings.
- [ ] Audit logging for privileged/admin actions.

## 7. Contracts & documents to prepare

| Document | Owner |
| --- | --- |
| Terms of service | Counsel **[FOUNDER INPUT]** |
| Privacy notice | Counsel **[FOUNDER INPUT]** |
| Worker terms / onboarding agreement | Counsel **[FOUNDER INPUT]** |
| Employer terms | Counsel **[FOUNDER INPUT]** |
| Verification consent notice | Counsel + KYC provider **[FOUNDER INPUT]** |
| Payment provider agreement | Counsel **[FOUNDER INPUT]** |
| DPA with KYC / payment / hosting providers | Counsel **[FOUNDER INPUT]** |
| Pilot employer LOI / agreement | Founder **[FOUNDER INPUT]** |
| Contractor / employee agreements | Counsel **[FOUNDER INPUT]** |

## 8. Ongoing obligations after launch

- Quarterly review of retention schedules, consent versions and provider agreements.
- Monthly review of dispute outcomes, trust incidents and any regulatory changes.
- Annual policy review and penetration test.
- Log every material change to Terms / Privacy with a dated changelog.
- Keep the public [roadmap](https://innovator123-sudo.github.io/kalla-lai/roadmap.html) and [trust page](https://innovator123-sudo.github.io/kalla-lai/trust.html) in sync with what is actually live.

---

**Related:** [`security-privacy/README.md`](../security-privacy/README.md) (technical threat model), [`site/privacy.html`](../site/privacy.html), [`site/terms.html`](../site/terms.html).
