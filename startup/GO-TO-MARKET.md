# Kalla-Lai — Go-to-Market Plan

**Principle:** density before geography, trust before volume. A thin marketplace that spans a whole country is worth less than a dense one that owns a few neighbourhoods.

> **[FOUNDER INPUT]** marks decisions that need real local knowledge before launch.

---

## 1. Launch wedge

| Decision | Recommendation | Confirm |
| --- | --- | --- |
| Geography | One city, then a small number of adjacent area clusters | **[FOUNDER INPUT: city]** |
| Category | One high-frequency, shift-based, easy-to-verify service category | **[FOUNDER INPUT: category]** |
| Side to build first | Workers (supply), then employers with recurring demand | **[FOUNDER INPUT]** |
| Duration | 8–12 week measured pilot before any expansion | **[FOUNDER INPUT]** |

**Why one category:** verification requirements, shift length, pricing norms and dispute patterns differ by category. Solving them once, properly, is the whole point.

**Why supply first:** employers churn permanently after two unfilled shifts. Workers tolerate an empty inbox for a while; employers do not.

## 2. Worker acquisition

1. **Verification camps** — in-person sessions in target areas that get a worker from signup to approved identity check in one sitting. Highest-conversion activation step and a trust-building moment.
2. **Referral loop** — a worker who completes a settled shift invites two others. Track invites → verified → first completed shift, not just installs.
3. **Local partnerships** — training centres, trade associations, community organisations, remittance/mobile-wallet touchpoints. **[FOUNDER INPUT: which exist in the launch city]**
4. **Profile quality help** — assist with portfolio photos and a short promo video; a complete profile materially improves match rates.
5. **Never pay for raw signups.** Pay or reward only for *verified, first-shift-completed* workers.

**Activation definition:** approved verification + a complete profile, not an account.

## 3. Employer acquisition

1. **Recurring demand first** — target households and small businesses that hire the same kind of help weekly, not one-off posters.
2. **Founder-led sales for the first 10–20** — sit with each employer, post their first requisition together, and watch the first shift end to end.
3. **Trust collateral** — the [trust & safety page](https://innovator123-sudo.github.io/kalla-lai/trust.html), the verification explanation and the dispute policy, in plain language and the local language.
4. **Pilot offer** — **[FOUNDER INPUT: fee waiver, guarantee or service-level commitment for pilot employers]**.
5. **Weekly check-in** — one structured conversation per pilot employer: fill rate, no-shows, payment experience, one thing to fix.

**Employer activation definition:** first requisition posted AND at least one shift settled.

## 4. The liquid marketplace loop

```
More verified workers in an area
   → better fill rate and faster matching
   → employers post again
   → more shifts available
   → workers earn and stay
   → more verified workers join via referral
```

Instrument every arrow. If one arrow stalls, fix that arrow — do not add geography.

## 5. Pilot design

| Element | Value |
| --- | --- |
| Duration | 8–12 weeks **[FOUNDER INPUT]** |
| Employers | 3–5 with recurring demand **[FOUNDER INPUT]** |
| Workers | Enough to hold a target fill rate in the chosen area clusters **[FOUNDER INPUT]** |
| Settlement | Real provider, real money, signed webhook confirmation — or explicitly labelled as a simulation |
| Instrumentation | [Pilot dashboard](METRICS.md#pilot-dashboard) live from day 1 |
| Review cadence | Weekly metrics + qualitative interviews with both sides |

**Success criteria — set these before the pilot starts, not after:**
- [ ] Fill rate above threshold **[FOUNDER INPUT]**
- [ ] Shift completion rate above threshold **[FOUNDER INPUT]**
- [ ] Settlement success rate above threshold **[FOUNDER INPUT]**
- [ ] 30-day repeat-hire rate above threshold **[FOUNDER INPUT]**
- [ ] Zero unresolved trust incidents **[FOUNDER INPUT]**
- [ ] Contribution per shift positive at the target take-rate **[FOUNDER INPUT]**

## 6. Expansion gates

Move to the next area or category only when all of these hold in the current one:

1. Fill rate and completion rate stable for 4 consecutive weeks.
2. Repeat-hire rate shows employers come back without founder intervention.
3. Dispute volume is handleable by the current ops capacity.
4. Contribution per shift is measured and positive.
5. Verification and settlement failure rates are inside agreed SLAs.

## 7. Messaging

| Audience | One line | Proof point |
| --- | --- | --- |
| Workers | "Get verified once, find work nearby, always know where your money stands." | Live app + visible payment states |
| Employers | "Know who's coming, what was agreed, and that it was settled." | Verification badge + shared record |
| Partners | "The trust layer for everyday work." | Open technical docs + honest roadmap |
| Investors | "Own the record of the shift, not the listing." | Working product + instrumented pilot |

**Tone:** plain, confident, specific. Never imply the product does something it does not yet do — especially payments and verification coverage.

## 8. Channels (in priority order)

1. Founder-led sales and in-person onboarding
2. Worker referrals and community partnerships
3. The public website (SEO on category + city intent, FAQ, trust content)
4. Open repository and technical documentation (partner credibility)
5. Local-language social / community groups
6. Paid acquisition — **only after** organic repeat-hire economics are measured

## 9. Anti-patterns

- Launching city-wide or category-wide on day one.
- Buying signups instead of verified, activated participants.
- Adding a second side's complexity before the first side is dense.
- Quoting unverified market-size numbers to partners.
- Describing the preview build as a production payments service.
- Expanding geography to hide a retention problem.
