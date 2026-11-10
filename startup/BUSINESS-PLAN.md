# Kalla-Lai — Business Plan (working draft)

**Version:** 1.0 · November 2026 · **Stage:** pre-seed, product built, pre-pilot
**Audience:** founders, early investors, pilot partners

> This plan deliberately contains no invented financial figures. Sections that need real numbers are marked **[FOUNDER INPUT]**. A forecast built from made-up inputs is worse than no forecast.

---

## 1. Executive summary

Kalla-Lai (कल्ला-लाई) is a two-sided marketplace for local, shift-based work. It replaces an informal chain — word of mouth, chat messages, cash — with one shared, verifiable journey: profile → identity verification → discovery or requisition → agreed shift → attendance → completion → settlement → review.

A working product already exists: a Flutter web client, a Node/TypeScript API with Supabase Postgres, a hosted identity-verification integration path, an escrow-style ledger model, and full public technical documentation. The company is pre-revenue and pre-pilot. The immediate work is legal setup, a licensed payment partner, an instrumented pilot in one city, and measured unit economics.

**The ask:** employer pilot partners, identity/payment infrastructure partners, and early-stage capital to fund a 90-day pilot and production hardening. **[FOUNDER INPUT: exact amount, instrument and target close date]**

## 2. Company

| Item | Value |
| --- | --- |
| Legal name | **[FOUNDER INPUT]** |
| Registration / tax ID | **[FOUNDER INPUT]** |
| Founded | **[FOUNDER INPUT]** |
| Founders | **[FOUNDER INPUT: names, roles, relevant experience]** |
| Location | Nepal-first **[FOUNDER INPUT: city / registered address]** |
| Legal structure | **[FOUNDER INPUT]** |
| Bank / payment accounts | **[FOUNDER INPUT]** |
| Website | https://innovator123-sudo.github.io/kalla-lai/ (replace with owned domain **[FOUNDER INPUT]**) |
| Repository | https://github.com/Innovator123-sudo/kalla-lai |

## 3. Market and problem

Local service work is high-frequency, recurring and almost entirely unbundled. Discovery, agreement, identity assurance, attendance and payment are handled separately — usually by the same two people over a phone. Job boards addressed discovery but not the transaction. The result is a market where neither side can price the risk of the other.

**Market sizing — to be completed properly.** Do not paste a top-down TAM number into a deck. Build it bottom-up:
1. Choose the launch city and the first 1–2 work categories. **[FOUNDER INPUT]**
2. Estimate addressable shifts per week from employer counts or household/business surveys, not from a national labour statistic.
3. Estimate realistic take-rate and achievable share after 12 / 24 / 36 months.
4. Show the calculation and its sources in the data room.

Until that work is done, the honest public statement is qualitative: *informal local work is large, recurring and underserved by trust infrastructure.*

## 4. Product

### 4.1 What ships today
See [STARTUP-PLAYBOOK.md §6](STARTUP-PLAYBOOK.md#6-what-actually-exists-today) and the [public roadmap](https://innovator123-sudo.github.io/kalla-lai/roadmap.html).

### 4.2 Differentiators
- **Honest state machine** — the UI cannot claim verification, publication or payment without an authoritative confirmation.
- **Data minimisation** — identity checks stay with a specialist provider; no document images or biometrics stored.
- **Two-sided trust** — employer credibility and worker reputation are both first-class.
- **Documentation as an asset** — architecture, workflows, security, privacy and QA are public, which shortens partner due diligence.

### 4.3 Product roadmap (summary)
| Phase | Content | Gate |
| --- | --- | --- |
| 1 — Done | Client, API, profiles, discovery, requisitions, shift states, KYC path, docs | — |
| 2 — Hardening | Licensed settlement, KYC/consent per market, secrets/CORS, E2E tests, pilots | Provider signed + counsel sign-off |
| 3 — Field-ready | Android/iOS, push, offline-tolerant flows, local-language accessibility | Pilot retention targets met |
| 4 — Scale | Reputation scoring, disputes SLA, insurance, employer tooling, multi-city | Repeat-hire economics hold |

## 5. Operations

### 5.1 The shift lifecycle
```
Profile → Verification → Discovery/Requisition → Agreement
   → Dispatch → Attendance → Completion → Review
   → Settlement → Reputation update → (Dispute if needed)
```
Each transition is an explicit, permissioned, auditable API state. The same record is visible to both sides.

### 5.2 Trust & safety operations
- Automated: signed provider webhooks, role checks, idempotency, rate limits, validation.
- Human: dispute triage, manual review of flagged accounts, incident log, escalation SLAs. **[FOUNDER INPUT: staffing per 1,000 shifts]**
- Hard rule: a provider session completing is never treated as approval; only a signed decision is.

### 5.3 Support
Channels and hours **[FOUNDER INPUT]**. Start with a single shared inbox and a documented escalation matrix; add in-app support once volume justifies it.

## 6. Unit economics framework

Build this in a spreadsheet with real pilot numbers. The structure:

```
Revenue per settled shift = gross shift value × take-rate
Variable cost per shift    = payment processing + KYC amortisation
                            + support minutes × cost/min
                            + dispute/incentive allowance
Contribution per shift    = revenue − variable cost
Employer CAC              = acquisition spend ÷ new hiring employers
Worker CAC                = acquisition spend ÷ activated verified workers
Payback                   = (employer CAC + worker CAC allocated)
                            ÷ (shifts per employer per month × contribution)
```

**Key sensitivities:** repeat-hire frequency, take-rate, dispute rate, KYC cost per verified worker, support load. **[FOUNDER INPUT: fill with provider quotes and pilot measurements]**

**Break-even condition:** contribution per shift × monthly settled shifts ≥ fixed monthly operating cost. Fixed cost lines: engineering, trust & safety ops, infrastructure, legal/compliance, admin. **[FOUNDER INPUT]**

## 7. Go-to-market

Full plan in [GO-TO-MARKET.md](GO-TO-MARKET.md). Summary: one city, one category, supply-first in tight geographic clusters, employer pilots with recurring demand, expand only when repeat-hire and fill rates hold.

## 8. Team and hiring

Current: small independent founding team **[FOUNDER INPUT: names]**.
First hires in priority order:
1. **Full-stack / marketplace engineer** — payments, state machine, reliability.
2. **Trust & safety / operations lead** — disputes, verification ops, employer support.
3. **Local growth / supply lead** — worker onboarding and area density.
4. **Counsel (fractional)** — labour, privacy, payments, contracts.

## 9. Milestones and use of funds

| Milestone | Evidence | Target |
| --- | --- | --- |
| Legal + production readiness | Entity, reviewed terms, rotated secrets, payment agreement | **[FOUNDER INPUT]** |
| End-to-end real settlement | Signed webhook confirms a real pilot payout | **[FOUNDER INPUT]** |
| First pilot | 3–5 employers, measured dashboard live | **[FOUNDER INPUT]** |
| Repeat-hire proof | 30-day repeat-hire rate above internal threshold | **[FOUNDER INPUT]** |
| Mobile field release | Android build in the hands of pilot workers | **[FOUNDER INPUT]** |

**Use of funds:** engineering, compliance/legal, payment and KYC provider costs, pilot operations, infrastructure. **[FOUNDER INPUT: amounts and runway]**

## 10. Financial plan

No projections are published yet. Produce a 24-month model only after the pilot supplies: settled shifts/month, average shift value, take-rate, KYC cost, payment cost, dispute rate and support minutes per shift. The model must show the calculation, not just the outputs.

## 11. Governance and compliance

See [LEGAL-CHECKLIST.md](LEGAL-CHECKLIST.md). Launch is gated on counsel sign-off for privacy/consent and on a signed payment-provider agreement. Neither is currently in place.

## 12. Risks

See [STARTUP-PLAYBOOK.md §14](STARTUP-PLAYBOOK.md#14-risk-register). The three that can kill the company fastest: payment partner access, KYC legality in the launch market, and supply density at pilot scale.

## 13. Decisions still open

- [ ] Launch city and first work category **[FOUNDER INPUT]**
- [ ] Fee model and take-rate hypothesis **[FOUNDER INPUT]**
- [ ] Payment provider and KYC provider contracts **[FOUNDER INPUT]**
- [ ] Open-source vs proprietary licensing **[FOUNDER INPUT]**
- [ ] Whether to raise now or after pilot data **[FOUNDER INPUT]**
- [ ] Owned domain and brand email **[FOUNDER INPUT]**
