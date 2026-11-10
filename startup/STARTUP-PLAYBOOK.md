# Kalla-Lai — Startup Playbook

**Status:** early-stage, product built, pre-pilot · **Last reviewed:** November 2026
**One-line company:** Kalla-Lai is the trust layer for everyday local work.

> Anything marked **[FOUNDER INPUT]** is a real-world fact that must be supplied before it appears in a deck, contract or public page. Nothing in this document invents traction, revenue or market size.

---

## 1. Vision, mission, positioning

| | |
| --- | --- |
| **Vision** | A world where anyone can take a day's work and be certain they will be paid, and anyone hiring can be certain who is arriving. |
| **Mission** | Make trusted work accessible to everyone by joining verification, a shared agreement and an auditable payment trail into one understandable journey. |
| **Positioning** | Not a job board. A transaction layer for local, shift-based work that both sides trust enough to settle through. |
| **Category** | Two-sided marketplace · workforce trust infrastructure · local services |
| **Geographic start** | Nepal-first **[FOUNDER INPUT: confirm launch city]** |

**Positioning statement**
> For independent workers and the households and businesses that hire them, Kalla-Lai is the marketplace that makes every shift verifiable — because identity, the agreement, attendance, completion and settlement all live in one shared record, unlike job boards that stop at the listing.

## 2. The problem

Everyday service work is still coordinated informally: found by word of mouth, agreed in chat, settled in cash.

- **Worker pain** — no portable proof of skill or reliability; every engagement restarts from zero; a completed shift is no guarantee of payment; no recourse when a dispute happens.
- **Employer pain** — no dependable way to check who is coming, whether they can do the job, or what to do when a shift goes wrong.
- **Shared pain** — the agreement, the attendance, the completion and the settlement live in scattered messages. There is no record to point to.

**Cost of the status quo:** lost income from no-shows and non-payment, time spent re-finding and re-vetting people for recurring work, and a ceiling on how far a good worker's reputation can travel.

## 3. Target customers

### Primary — worker
Independent service providers doing shift-based local work. Profile: smartphone-first, area-bound, repeat work, income depends on being trusted quickly. Job to be done: *"Find tomorrow's shift with someone reliable, and know I'll be paid."* **[FOUNDER INPUT: pick the first 1–2 categories]**

### Primary — employer
Households and small businesses with recurring, predictable shift demand. Job to be done: *"Get a verified person here on time, with a clear record of what was agreed and paid."*

### Secondary
Staffing agencies, property managers, small contractors, facilities teams — higher volume, more structured processes, natural expansion path.

### Explicitly not the first customer
Full-time salaried hiring, remote knowledge work, cross-border recruiting, large enterprise procurement. These dilute the wedge.

## 4. Value proposition

| For workers | For employers |
| --- | --- |
| One profile that compounds with every completed shift | Verified identities before someone arrives |
| Verify once, carry the trust signal everywhere | Structured requisitions instead of chat threads |
| Area-based discovery with clear terms up front | Attendance, completion and review in one place |
| Visible payment state from agreement to settlement | Rich company profile that builds trust back |
| Reputation and portfolio that travel with them | A dispute path with an actual record |

## 5. Product principles (non-negotiable)

1. **Never claim what the system hasn't confirmed.** No "verified" badge without an approved provider decision; no "paid" label without a confirmed settlement; no "published" job without a persisted requisition.
2. **Privacy by design.** Hosted KYC provider does the checking; we store a session reference, consent record and decision state — not documents, face templates or home addresses.
3. **Both sides, always.** Worker reputation and employer credibility are designed together.
4. **Open by default.** Architecture, workflow, security, privacy and QA decisions are documented in the public repo.
5. **Fail visibly.** If a provider is down or a state is unknown, say so rather than showing a reassuring lie.

## 6. What actually exists today

- Flutter web client: animated intro, worker/employer journey, settings, persisted email/Google sessions, worker and employer rich profiles, discovery, hiring requisitions, shift/escrow-ledger states, admin people console.
- Node/TypeScript API: role-based access, idempotency, structured errors, versioned SQL migrations, Supabase Postgres, signed verification webhook path.
- Hosted identity verification integration (document OCR, selfie comparison, liveness) with HMAC-signed decision webhook.
- Public documentation: architecture, workflows, data, API/realtime, security/privacy, UI/UX & QA.
- Public startup website with pitch deck, investor brief, roadmap, FAQ and legal drafts.

**Not live yet:** licensed payment settlement and payouts, per-market KYC/consent review, private object storage for profile media, mobile apps, legal/labour review, full release testing.

## 7. Business model

| Layer | Mechanism | Status |
| --- | --- | --- |
| Core | Transparent service / transaction fee on completed, settled shifts | Designed, **not live** — needs a payment partner |
| Expansion | Employer SaaS: bulk shifts, invoicing, workforce analytics | Planned |
| Adjacent | Verification-as-a-service, insurance/guarantee partnerships | Optional, later |

**Pricing is a pilot question, not a deck assumption.** Take-rate depends on measured willingness to pay, replacement cost of informal hiring, and payment-processing cost in the launch market. **[FOUNDER INPUT: target take-rate hypothesis and payment cost quotes]**

## 8. Why now

- Smartphone, camera and connectivity are already in every pocket.
- Hosted document + liveness verification is an API a small team can buy.
- Digital settlement is normal behaviour; expectations around instant, traceable payment are set.

The remaining gap is a trusted record of the work itself — a product problem, not an infrastructure problem.

## 9. Competitive landscape

| Alternative | What it does well | Where it stops |
| --- | --- | --- |
| Word of mouth / chat groups | Zero friction, high trust within a network | Doesn't scale, no record, no verification, no recourse |
| General job boards | Listing volume and reach | Stop at discovery; don't know who showed up or whether payment was right |
| Classifieds / social groups | Huge supply of casual listings | No verification, no agreement, no settlement, high fraud |
| Agency staffing | Vetting and replacement | Expensive, slow, opaque, out of reach for a single shift |

**Our bet:** win on *trust per transaction*, not on listing count. Own the record of the shift.

## 10. Moat

1. **Trust history compounds** — every completed shift adds verified identity, attendance, completion, settlement and review. The second hire is cheaper, the tenth nearly frictionless.
2. **Two-sided data** — employer reliability signals are as valuable as worker reputation, and only a platform that serves both can collect them.
3. **Operational density** — area-by-area supply and repeat demand are slow to replicate once the loop is running.
4. **Regulatory and provider relationships** — KYC and payment integrations, consent flows and dispute handling become defensible operational know-how.

## 11. North-star metric and KPIs

**North star: verified, completed and settled shifts per week.** It only counts when all three happened — which is exactly the outcome the company promises.

See [METRICS.md](METRICS.md) for exact definitions, the pilot dashboard and anti-metrics. Headline set: worker activation, verification pass rate, fill rate, shift completion rate, settlement success, 30-day repeat-hire rate, employer retention, take-rate contribution.

## 12. Go-to-market in one paragraph

Pick one city and one high-frequency, shift-based category. Build worker supply first in a few tight geographic clusters (verification camps, referrals, local partnerships), then sign a small number of employers with recurring demand and run a measured pilot. Expand category-by-category only after repeat-hire and settlement rates hold. Full plan: [GO-TO-MARKET.md](GO-TO-MARKET.md).

## 13. First 90 days

| Days | Focus | Exit criterion |
| --- | --- | --- |
| 0–30 | Legal entity, domain, real inbox, counsel review of privacy/terms, payment partner shortlist, production secrets rotation | Can legally and operationally accept pilot users |
| 31–60 | Payment provider integration with signed webhooks, KYC consent/retention review, instrumentation of the pilot dashboard, 3–5 employer LOIs | End-to-end verified → shift → settled loop works with real money in a test environment |
| 61–90 | Live pilot in one area, weekly metric review, weekly worker/employer interviews, publish honest results | Measured repeat-hire and completion rates; a documented decision on whether to scale |

**[FOUNDER INPUT: budget, team availability and target pilot start date]**

## 14. Risk register

| Risk | Severity | Mitigation | Owner |
| --- | --- | --- | --- |
| Payment partner delays or declines | High | Shortlist 2–3 providers early; keep ledger model provider-agnostic | **[FOUNDER INPUT]** |
| KYC coverage / consent not accepted in launch market | High | Local counsel review before any verification goes live | **[FOUNDER INPUT]** |
| Supply density too thin → unfilled shifts | High | Area-by-area concentration; never expand geography before fill rate holds | **[FOUNDER INPUT]** |
| Both sides bypass the platform after first match | Medium | Make verification, dispute cover and payment record worth keeping on-platform | **[FOUNDER INPUT]** |
| Fraud, impersonation, fake shifts | High | Signed webhooks, role-based access, rate limits, anomaly review, honest UI states | Engineering |
| Labour-law / worker-classification change | Medium | Counsel review; design as a marketplace, not an employer | **[FOUNDER INPUT]** |
| Trust damage from an early bad incident | High | Fast dispute resolution, clear escalation, transparent incident log | **[FOUNDER INPUT]** |
| Data breach | High | Data minimisation, secrets in a manager, RLS, audit log, incident plan | Engineering |

## 15. What we will not do

- Fabricate traction, market size or pricing data to make the deck look better.
- Claim verification or payment happened before an authoritative system confirms it.
- Store identity documents or biometric templates on our own infrastructure.
- Scale geography before the trust loop closes end to end in one place.
- Treat the preview build as a production financial service.
