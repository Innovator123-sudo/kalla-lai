# Kalla-Lai — Metrics & Definition of Done

**Rule:** a metric is only useful if two people compute it the same way. Every definition below names the event source and the denominator.

---

## 1. North-star metric

### Verified, completed & settled shifts per week (VCSS)

A shift counts **once**, and only when all four are true in the system of record:

1. The worker had an **approved** verification decision confirmed by a signed provider webhook.
2. The shift reached the `COMPLETED` state with both sides' attendance recorded.
3. A **confirmed settlement** exists from the payment provider (not a UI label, not a ledger intent).
4. No open dispute at the time of measurement.

**Why this one:** it is the exact promise of the company. Growth in signups, listings or even completed shifts is not success unless the money and the trust layer actually closed.

---

## 2. Funnel definitions

| Metric | Numerator | Denominator | Source |
| --- | --- | --- | --- |
| Signup | Accounts created | — | `users` |
| Verification start | Sessions created with explicit consent | Signups | verification session records |
| Verification pass rate | Approved decisions | Verification starts | signed provider webhook |
| **Worker activation** | Approved verification + complete profile | Signups | profiles + verification state |
| Employer activation | First requisition posted AND ≥1 shift settled | Employer signups | requisitions + settlements |
| Match rate | Requisitions with ≥1 suitable applicant | Requisitions posted | applications |
| **Fill rate** | Requisitions with a confirmed assignment | Requisitions posted | dispatch records |
| Shift completion | Shifts in `COMPLETED` | Assigned shifts | shift state machine |
| Settlement success | Confirmed settlements | Completed shifts | payment webhook |

**"Complete profile"** = required identity fields, area, at least one skill/category and a contact method. Define once in code, not per analysis.

---

## 3. Retention & quality

| Metric | Definition | Why it matters |
| --- | --- | --- |
| 30-day repeat-hire rate | Employers who post and settle again within 30 days ÷ employers with a first settled shift | The single best proof the marketplace creates value |
| Worker 30-day return | Activated workers completing ≥1 shift in two consecutive 30-day windows ÷ activated workers with a first shift | Supply durability |
| No-show rate | Assigned shifts with no attendance ÷ assigned shifts | Trust damage early-warning |
| Dispute rate | Disputes opened ÷ completed shifts | Ops load and product clarity |
| Dispute resolution time | Median hours from open to resolved | Whether the trust layer actually works |
| Time to fill | Median hours from requisition posted to confirmed assignment | Liquidity in an area |
| Verification turnaround | Median time from consent to approved decision | Onboarding friction |
| Settlement latency | Median time from completion to confirmed settlement | Worker trust |

**Segment everything by area cluster and category.** Averages across a thin marketplace hide exactly the problem you need to find.

---

## 4. Unit economics

```
Revenue per settled shift   = gross shift value × take-rate
Variable cost per shift     = payment processing
                            + KYC cost amortised over verified shifts
                            + support minutes × cost per minute
                            + dispute / incentive allowance
Contribution per shift      = revenue − variable cost
Employer CAC                = acquisition spend ÷ activated employers
Worker CAC                  = acquisition spend ÷ activated workers
CAC payback (months)        = (employer CAC + allocated worker CAC)
                              ÷ (settled shifts per employer per month × contribution)
```

Report contribution **per settled shift** and **per activated employer per month**. Both are needed: one exposes pricing, the other exposes frequency.

**[FOUNDER INPUT: provider quotes, support cost per minute, target take-rate]**

---

## 5. Trust & safety metrics

| Metric | Target |
| --- | --- |
| Claims shown without authoritative confirmation | **0** (hard invariant, monitored in tests) |
| Verification state mismatch between provider and app | 0 |
| Failed / malformed webhook signatures rejected | 100% |
| Unresolved trust incidents at week end | **[FOUNDER INPUT: SLA]** |
| Data-retention policy violations | 0 |

The first row is a product invariant, not a KPI to optimise. See the "never claim what the system hasn't confirmed" principle in [STARTUP-PLAYBOOK.md §5](STARTUP-PLAYBOOK.md#5-product-principles-non-negotiable).

---

## 6. Pilot dashboard

One page, reviewed weekly, visible to the whole team:

1. **VCSS** — this week, last 4 weeks trend
2. **Funnel** — signup → verification → activation → requisition → fill → complete → settle (counts and conversion at each step)
3. **Liquidity** — fill rate and time-to-fill by area cluster
4. **Quality** — no-show, dispute, resolution time
5. **Retention** — 30-day repeat-hire, worker 30-day return
6. **Economics** — contribution per shift, CAC, payback
7. **Trust** — the invariant checks above
8. **Qualitative** — the three most common things workers and employers said this week

---

## 7. Anti-metrics (do not optimise these)

- **Registered users** — easy to buy, says nothing about trust or liquidity.
- **Job posts / listings** — the insight is that listings are not the business.
- **App installs / page views** — vanity at pilot scale.
- **Gross shift value alone** — can grow while contribution stays negative.
- **Verification "starts"** — only approved decisions create supply.
- **Average rating without dispute context** — early ratings are inflated and gameable.

---

## 8. Instrumentation requirements before pilot

- [ ] Every state transition emits an event with shift id, actor role, timestamp and correlation id
- [ ] Provider webhooks log decision + signature verification outcome, never payloads with personal data
- [ ] Settlement events are distinguishable from ledger intents
- [ ] Denominators are queryable from the same system of record as numerators
- [ ] Area cluster and category are set on every shift
- [ ] The dashboard can be recomputed from raw events, not just read from a cache
- [ ] A test asserts no UI state can display "verified"/"paid" without a confirmed source event

**[FOUNDER INPUT: owner and deadline for each item]**
