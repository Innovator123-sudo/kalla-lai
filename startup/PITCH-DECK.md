# Kalla-Lai — Pitch Deck (11 slides)

Markdown version of the [interactive deck](https://innovator123-sudo.github.io/kalla-lai/pitch.html). Use arrow keys there; use this file for editing, printing or sending ahead of a meeting.

**Rule:** no invented metrics. If a number is not measured, it is not on a slide.

---

## Slide 1 — Title

# Kalla-Lai
### Work, verified.

A trusted two-sided marketplace for everyday local work — starting in Nepal.

*Early-stage · Product built · Pilots next*

**Speaker note:** open with the fact that the product is live and openable from the website. This is not a concept deck.

---

## Slide 2 — Problem

# Everyday work still runs on promises

Found by word of mouth. Agreed in chat. Settled in cash.

- Workers have no portable proof of reliability
- Employers cannot check who is arriving
- Neither side has a shared record when something goes wrong

**Speaker note:** the pain is not finding people. It is not knowing whether the shift happened and the payment was right.

---

## Slide 3 — Insight

# The gap isn't discovery. It's trust.

Job boards solved listing volume and stopped. They don't know whether the person showed up, the work was completed, or the payment was right.

> The durable business is the layer both sides trust enough to **settle through**.

**Speaker note:** this is the strategic bet. Everything in the product follows from it.

---

## Slide 4 — Solution

# One shared journey, both sides

- Verified identity through a specialist KYC provider
- Rich worker and employer profiles with reputation
- Area-based discovery and structured requisitions
- Shift, attendance, completion and review states
- Escrow-style ledger with a dispute path

**Speaker note:** walk the state machine left to right; each arrow is an auditable API transition.

---

## Slide 5 — Why now

# The infrastructure finally got cheap

- A smartphone, camera and connectivity in every pocket
- Hosted document + liveness verification as an API
- Digital settlement is already normal behaviour

The remaining work is product and operations — not fundamental infrastructure.

---

## Slide 6 — Product

# Built, not mocked up

- Working Flutter web client — open it from the website
- Live Node/TypeScript API with Supabase Postgres
- Role-based access, migrations, signed verification webhook
- Open architecture, workflow, security, privacy and QA docs

**Speaker note:** offer to open the app live. Being able to click through it is the strongest slide.

---

## Slide 7 — Trust

# Honesty is a feature

The UI never claims a worker was verified, money moved, or a job was published unless an authoritative service confirms it.

No identity images or biometric templates stored — only a session reference, consent record and decision state.

**Speaker note:** this is also the answer to "what happens when your KYC provider is wrong or down?" — we show unknown, not green.

---

## Slide 8 — Model

# Transparent take on settled shifts

**Primary:** a transparent service or transaction fee on completed, settled shifts.
**Expansion:** employer tooling — bulk shifts, invoicing, workforce analytics.

*Pricing and unit economics are pilot questions, not deck assumptions.*

---

## Slide 9 — Moat

# Repetition compounds

Every completed shift leaves a verified record: who did the work, what was agreed, that it was completed and settled.

The second hire is cheaper, the tenth nearly frictionless. **The moat is the trust history, not the listing count.**

---

## Slide 10 — Stage & risks

# What's real, what's open

**Real:** working product, live API, documented architecture, KYC integration path, ledger model.

**Open:** licensed settlement, per-market KYC/consent review, supply density, legal review, mobile release.

**Speaker note:** do not soften this slide. Investors who have seen marketplaces before will find the gaps anyway; naming them first builds credibility.

---

## Slide 11 — Ask

# Let's run a pilot

Looking for:
- Employer partners with recurring shift demand
- Identity / payment / insurance infrastructure partners
- Early-stage investors with marketplace operating experience

**Contact:** [kalla-lai/contact](https://innovator123-sudo.github.io/kalla-lai/contact.html)

---

## Appendix slides (prepare, don't present unless asked)

- **A1 — Lifecycle diagram:** profile → verification → match → agreement → attendance → completion → settlement → reputation
- **A2 — Data minimisation:** exactly which fields are stored for verification, and which stay with the provider
- **A3 — Competitive matrix:** word of mouth / job boards / classifieds / agencies vs Kalla-Lai
- **A4 — Pilot design:** city, category, employer count, duration, dashboard metrics (see [METRICS.md](METRICS.md))
- **A5 — Unit economics formula:** see [BUSINESS-PLAN.md §6](BUSINESS-PLAN.md#6-unit-economics-framework)
- **A6 — Risk register:** see [STARTUP-PLAYBOOK.md §14](STARTUP-PLAYBOOK.md#14-risk-register)
- **A7 — Technical architecture:** link to [`architecture/README.md`](../architecture/README.md)
- **A8 — 90-day plan:** see [STARTUP-PLAYBOOK.md §13](STARTUP-PLAYBOOK.md#13-first-90-days)

---

## Before sending this deck externally

- [ ] Add real founder names and contact details **[FOUNDER INPUT]**
- [ ] Confirm launch city / category **[FOUNDER INPUT]**
- [ ] Replace the qualitative market statements with a sourced bottom-up estimate once available
- [ ] Replace "pilots next" with actual pilot data after the first cohort
- [ ] Confirm the ask (amount, instrument, use of funds) **[FOUNDER INPUT]**
- [ ] Have counsel review any claim about verification, payments or worker classification
