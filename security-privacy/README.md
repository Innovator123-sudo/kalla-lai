# Security & Privacy README

## 1. Security objective

Kalla-Lai handles identity evidence, contact details, location, work history, chat, and payment-related records. The goal is to reduce the likelihood and impact of account takeover, unauthorized data access, location exposure, payment manipulation, fake listings, malicious uploads, insider misuse, and service disruption.

No control can guarantee that an application will never be breached. Security is a continuing engineering and operational responsibility.

## 2. Threats and required controls

| Threat | Required controls |
|---|---|
| Account takeover | Verified contact methods, MFA/passkeys where feasible, rate-limited login/OTP/recovery, suspicious-login detection, session revocation |
| Insecure object access (BOLA/IDOR) | Server-side ownership/relationship checks on every protected resource; automated negative authorization tests |
| Privilege escalation | RBAC, least privilege, separate admin identities, sensitive-action re-authentication, access reviews |
| API abuse | Schema validation, bounded payloads, rate limits, request throttling, safe errors, CORS/CSRF protections where applicable |
| Secret leakage | Managed secret store, environment separation, CI secret scanning, rotation, no privileged secrets in mobile apps |
| Identity-data exposure | Restricted vault/storage, short-lived authorized access, encryption, access audit, minimization and deletion policy |
| Location leakage | Coarse discovery location, precise location only when necessary, shift-scoped tracking, strict subscription authorization, short retention |
| Malicious uploads | File type allow-list, signature inspection, file-size limits, malware scanning, random object names, private storage |
| Payment manipulation | Signed webhooks, idempotency, provider reconciliation, server-authoritative payment states, immutable ledger entries |
| Insider misuse | Least privilege, MFA, audit logs, approval for sensitive actions, periodic access reviews |
| Data loss / outage | Encrypted backups, restore drills, alerting, tested incident response and recovery procedures |

## 3. Authentication and sessions

- Use a mature identity provider or a security-reviewed authentication implementation.
- Verify contact channels before allowing sensitive account actions.
- Offer passkeys or MFA where feasible, especially for employer/admin and high-risk operations.
- Rate-limit login, OTP, password reset, and account recovery flows.
- Use short-lived access tokens and rotated/revocable refresh tokens, or secure server sessions.
- For web surfaces, use Secure, HttpOnly, and appropriate SameSite cookie settings; defend against CSRF.
- Provide device/session management and a way to revoke other sessions.
- Require re-authentication for changing payout details, exporting sensitive data, or other high-impact actions.

## 4. Authorization and administrative access

Authentication answers “who are you?” Authorization answers “may you access this exact resource?” Every server endpoint and real-time subscription must enforce both.

Suggested roles from the product specification:

- Standard user / worker.
- Employer or corporate recruiter.
- Platform moderator.
- Billing administrator.

Use least-privilege scopes and object-level checks. Support personnel should not have broad access to identity documents or financial data simply because they have a support role. Log administrative reads and writes to sensitive records.

## 5. Encryption, secrets, and infrastructure

The source specifies TLS 1.3 for client-server communication and AES-256 encryption for database volumes and media assets, with managed, rotating KMS keys.

Implementation checklist:

- Enforce TLS 1.2+ (prefer TLS 1.3) on every public connection.
- Encrypt storage and backups using managed keys.
- Restrict key-management permissions separately from application runtime permissions.
- Rotate keys and credentials under a documented process.
- Keep production secrets out of source control, client bundles, mobile binaries, chat, and logs.
- Segment environments and internal services; do not expose internal service endpoints publicly.
- Disable debug endpoints and verbose production errors.

## 6. Sensitive records and uploads

- Keep identity documents, OCR output, and any biometric-related material in a restricted storage boundary separate from ordinary profile data.
- Avoid storing raw facial embeddings/templates unless necessity, lawful basis, consent, and a documented retention plan have been established.
- Prefer retaining only a verification outcome and minimal provider reference where sufficient.
- Store CVs, video pitches, and identity files in private object storage, not public buckets.
- Check file signatures and scan content; do not trust file extensions or client MIME types.
- Use expiring signed URLs only after server-side authorization.
- Never show a worker's raw identity document to an employer as a profile feature.

## 7. Location privacy

- Ask for location permission at the point a location-based feature is used.
- Explain purpose and provide manual location search where possible.
- Use approximate location for discovery whenever practical.
- Restrict precise live location to authorized participants and active shift workflows.
- Stop active tracking when the shift ends or the worker is offline.
- Define TTLs for Redis location entries and a specific, approved retention rule for any durable location evidence.
- Do not log exact coordinates by default.

## 8. Payment and financial integrity

- Use a reputable payment provider and verify provider-specific legal/operational availability in Nepal.
- Do not store card numbers or CVV in Kalla-Lai systems.
- Verify signed webhooks, deduplicate provider event ids, and use idempotency keys.
- Maintain an auditable ledger; use compensating/reversal entries rather than rewriting financial history.
- Reconcile internal payment state with provider settlement records.
- Never release held funds solely because a client says the payment succeeded.
- Have finance/legal owners approve escrow/holding structure, settlement triggers, refunds, fees, and tax treatment.

## 9. Privacy, consent, and user rights

The addendum calls for plain-language privacy information and workflows for access, correction, export, and deletion. It also names GDPR/CCPA-style rights, but implementing features alone does not establish legal compliance.

Before launch:

- Review applicable Nepal privacy, labor, identity-verification, biometric, and payment requirements with qualified local counsel.
- Explain what is collected, purpose, recipients, retention, and user controls.
- Obtain separate informed consent where required for identity checks, biometrics, background location, and optional marketing.
- Define retention periods and deletion/anonymization behavior for each data category.
- Keep production data out of demos, local development, and test fixtures; use synthetic data.
- Document exceptions where records must be retained for legal, financial, or dispute reasons.

## 10. Logging, monitoring, and incident response

Log security-relevant events such as login failures, session revocations, role changes, sensitive-document access, payment webhook failures, and unusual data-access volume.

Never log passwords, OTPs, access tokens, full identity numbers, raw biometric data, payment credentials, or unnecessary precise location.

Prepare an incident plan with:

- severity definitions and incident owners;
- containment and credential/key rotation procedures;
- evidence preservation and investigation steps;
- privacy/legal notification assessment;
- user/support communications;
- recovery and post-incident review.

## 11. Security verification before launch

- Threat model and data-flow review.
- Static analysis, dependency scanning, secret scanning, and container/image scanning where used.
- Automated authorization tests for every private resource type.
- Dynamic security testing against a staging environment.
- Mobile application security review.
- Independent penetration test before handling real identity and payment data.
- Tests for replayed webhooks, duplicate payment actions, malicious uploads, recovery abuse, rate-limit bypass, and location leakage.
- No unresolved critical or high-severity finding at launch without documented risk acceptance and compensating mitigation.

## 12. Security incident / vulnerability reporting

Publish a security contact and responsible-disclosure process. Assign owners and patch deadlines by severity. Do not promise a bounty unless the organization has approved and funded one.
