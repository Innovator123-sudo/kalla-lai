# Kalla-Lai — Fundraising & Data Room

**Stage:** pre-seed, product built, pre-pilot · **Public materials:** [investor brief](https://innovator123-sudo.github.io/kalla-lai/investors.html) · [pitch deck](https://innovator123-sudo.github.io/kalla-lai/pitch.html) · [roadmap](https://innovator123-sudo.github.io/kalla-lai/roadmap.html)

> **[FOUNDER INPUT]** marks items that only the founders can supply. Never put an invented number in a data room.

---

## 1. Fundraising strategy

**Recommendation:** raise enough to complete production hardening and a measured pilot, then return with real repeat-hire and contribution data. A marketplace with even modest but *measured* retention is worth more than one with a beautiful top-down TAM.

| Round | Purpose | Evidence to show before raising |
| --- | --- | --- |
| Pre-seed (now) | Legal setup, payment partner, 90-day pilot, 2–3 hires | Working product, open docs, honest risk register, pilot LOIs |
| Seed (after pilot) | Scale the winning area/category, field-ready mobile, trust & safety ops | 30-day repeat-hire, fill rate, settlement success, contribution per shift |

**Amount, instrument, valuation and target close:** **[FOUNDER INPUT]**

## 2. Data room index

Everything an investor or partner needs, and where it lives:

| Folder | Contents | Status |
| --- | --- | --- |
| `01-company` | Entity documents, cap table, founders' agreement | **[FOUNDER INPUT — not in repo]** |
| `02-product` | Live app link, screenshots, architecture README, workflow docs | ✅ Public |
| `03-technology` | API/realtime, data/memory, security/privacy, UI/UX & QA docs | ✅ Public |
| `04-market` | Bottom-up market estimate, category research, competitor matrix | **[FOUNDER INPUT]** |
| `05-traction` | Pilot dashboard, cohort tables, raw event export | Not yet — pilot not started |
| `06-economics` | Unit-economics model, provider quotes, 24-month forecast | Model structure in [BUSINESS-PLAN.md §6](BUSINESS-PLAN.md#6-unit-economics-framework); inputs **[FOUNDER INPUT]** |
| `07-legal` | Reviewed terms/privacy, provider agreements, labour-law opinion, IP assignment | Drafts only — see [LEGAL-CHECKLIST.md](LEGAL-CHECKLIST.md) |
| `08-team` | Bios, roles, hiring plan, advisor list | **[FOUNDER INPUT]** |
| `09-plan` | Startup playbook, business plan, GTM, metrics, roadmap | ✅ Public |
| `10-risks` | Risk register, incident log, open decisions | ✅ Public |

**Rule:** keep sensitive documents out of the public repository. The repo holds strategy and technical documentation, not contracts, cap tables or credentials.

## 3. What we can prove today

- A working end-to-end client, not a mockup — openable from the website.
- A live API with a real database, role-based access and versioned migrations.
- A designed, documented integration path for hosted identity verification with signed decision webhooks.
- An escrow-style ledger model with review and dispute states.
- Full public architecture, workflow, security, privacy and QA documentation.
- A startup operating kit with defined metrics, GTM, risk register and legal gates.

## 4. What we cannot prove yet (and say so)

- Licensed payment settlement and payouts.
- KYC coverage and consent legality at launch-market scale.
- Supply density, fill rate, completion rate, repeat-hire rate.
- Unit economics or a defensible take-rate.
- Legal entity, counsel sign-off, team track record, revenue.

## 5. Investor FAQ (honest answers)

**Is this a job board?** No. Job boards stop at the listing. We own the record of the shift — verification, agreement, attendance, completion, settlement, reputation.

**Do you hold money?** Not today. The ledger models the states; real settlement requires a licensed provider and is the top roadmap item. We never describe the preview as a payment service.

**How is verification handled?** By a hosted specialist provider. We keep a session reference, consent version/time and decision state — not documents, face templates or OCR data. Approval arrives via an HMAC-signed webhook.

**Why will this be defensible?** Trust history compounds. Every completed shift makes the next hire cheaper for that employer and the next job easier for that worker. Plus two-sided data and area-level operational density.

**What's the moat against a big classifieds platform?** They optimise listing volume. We optimise settlement-grade trust, which requires different state machines, provider relationships, consent flows and dispute operations. **[FOUNDER INPUT: strengthen with local regulatory/partnership specifics]**

**What are the biggest risks?** Payment partner access, KYC legality in the launch market, and supply density at pilot scale. See the [risk register](STARTUP-PLAYBOOK.md#14-risk-register).

**What will the money be used for?** Engineering, compliance/legal, provider costs, pilot operations, infrastructure. **[FOUNDER INPUT: exact split and runway]**

**Why no market-size number in the deck?** Because we haven't built a sourced bottom-up estimate for the launch city and category. We will publish it with the calculation when we have it.

**Can we talk to pilot employers?** Yes — once LOIs are signed and they've agreed to be referenced. **[FOUNDER INPUT]**

## 6. Milestone-based plan

| Milestone | Unlocks | Evidence |
| --- | --- | --- |
| Legal + secrets + reviewed policies | Ability to accept real users | Signed documents, rotated secrets |
| Payment provider live | Real settlement | Signed webhook confirming a real pilot payout |
| Pilot week 4 | First funnel data | Dashboard snapshot |
| Pilot week 8–12 | Retention and contribution data | Cohort table, unit-economics model |
| Repeat-hire proof | Seed round / geographic expansion | 30-day repeat-hire rate above pre-set threshold |

**Thresholds:** **[FOUNDER INPUT — set before the pilot begins, not after seeing results]**

## 7. Outreach

**Target profile:** early-stage investors with marketplace / fintech / emerging-market operating experience; identity and payment infrastructure partners; employer organisations with recurring shift demand.

**First message template (short):**
> We're building Kalla-Lai, a trust layer for everyday local work in Nepal. The product is live and open-source documented: [website]. We're pre-pilot, and the open items are licensed settlement and a measured employer pilot — not a concept. Would a 20-minute walkthrough be useful?

Replace the GitHub Pages URL with the owned domain once available **[FOUNDER INPUT]**.

## 8. Before any external send

- [ ] Real founder names, roles and contact details in the deck and website **[FOUNDER INPUT]**
- [ ] Legal entity and reviewed terms in place **[FOUNDER INPUT]**
- [ ] Data room folders 01, 04, 07, 08 populated **[FOUNDER INPUT]**
- [ ] Pilot LOIs signed **[FOUNDER INPUT]**
- [ ] The ask (amount, instrument, use of funds) decided **[FOUNDER INPUT]**
- [ ] Every claim in the deck traced to a source in the repo or the data room
