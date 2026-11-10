# Kalla-Lai Startup Kit

Everything needed to turn the working product in this repository into a real company. The website at [innovator123-sudo.github.io/kalla-lai](https://innovator123-sudo.github.io/kalla-lai/) is the public face; this folder is the operating layer behind it.

> **Read this first:** Kalla-Lai is an early-stage product. These documents are honest working drafts. Anything that requires a real-world fact we do not have — legal entity, founder names, registered address, bank details, traction numbers, pricing, market-size estimates — is marked **[FOUNDER INPUT]**. Do not publish those fields as facts until they are true.

## The kit

| Document | What it answers |
| --- | --- |
| [STARTUP-PLAYBOOK.md](STARTUP-PLAYBOOK.md) | The whole company on one page: vision, customers, value proposition, business model, moat, KPIs, 90-day plan, risks |
| [BUSINESS-PLAN.md](BUSINESS-PLAN.md) | Detailed plan: product, market, operations, unit economics framework, hiring, milestones, funding use |
| [PITCH-DECK.md](PITCH-DECK.md) | The 11-slide investor narrative (mirrors the [live pitch deck](https://innovator123-sudo.github.io/kalla-lai/pitch.html)) |
| [GO-TO-MARKET.md](GO-TO-MARKET.md) | Launch geography, wedge category, supply-first playbook, employer acquisition, pilot design |
| [METRICS.md](METRICS.md) | Exact metric definitions, the north-star metric, the pilot dashboard, anti-metrics |
| [BRAND-GUIDE.md](BRAND-GUIDE.md) | Name, colours, typography, logo usage, voice and tone, content rules |
| [LEGAL-CHECKLIST.md](LEGAL-CHECKLIST.md) | Entity, labour law, KYC/privacy, payments, insurance, contracts, launch gates |
| [FUNDRAISING.md](FUNDRAISING.md) | Stage, data room, what to raise for, investor FAQ, milestone-based plan |

## Related repository documentation

The technical side is already documented in depth:

- [`../README.md`](../README.md) — developer overview and setup
- [`../architecture/README.md`](../architecture/README.md) — system boundaries and technology choices
- [`../workflows/README.md`](../workflows/README.md) — worker, employer, verification, dispatch and payment flows
- [`../data-memory/README.md`](../data-memory/README.md) — persistence, cache and retention boundaries
- [`../api-realtime/README.md`](../api-realtime/README.md) — API domains, contracts and WebSocket events
- [`../security-privacy/README.md`](../security-privacy/README.md) — threat model, auth, privacy and payments
- [`../uiux-quality/README.md`](../uiux-quality/README.md) — design system, accessibility and quality gates

## Founder setup checklist

Work through these in order. Items 1–6 are the ones that currently make the website's contact flow and legal pages "drafts" rather than finished.

- [ ] **1. Legal entity** — register the company, get a tax ID and a business bank account. **[FOUNDER INPUT]**
- [ ] **2. Real inbox** — set up `hello@<your-domain>` and replace the GitHub-issue contact flow in `site/contact.html` (regenerate via `python tools/build_site.py`). **[FOUNDER INPUT]**
- [ ] **3. Domain** — point a real domain at the GitHub Pages site; update `og:url`, `sitemap.xml`, `robots.txt` and the JSON-LD block in `tools/build_site.py`.
- [ ] **4. Legal review** — have a lawyer in the launch jurisdiction review `site/privacy.html` and `site/terms.html`, plus the KYC consent flow. Remove the "draft" banners only after sign-off.
- [ ] **5. Payment partner** — sign with a licensed provider, implement webhook-confirmed settlement, then update every page that says the product does not move money yet.
- [ ] **6. Production secrets** — rotate the JWT/webhook secrets, lock down CORS to the production origins, move Firebase/Veriff credentials into a secret manager, set `DEMO_MODE=false`.
- [ ] **7. Pilot** — recruit 3–5 employers with recurring shift demand and instrument the [pilot dashboard](METRICS.md#pilot-dashboard).
- [ ] **8. Measure** — publish real retention, completion and repeat-hire numbers; replace the qualitative claims in `investors.html`.
- [ ] **9. Team page** — add real names, roles and photos to `about.html`.
- [ ] **10. Decide licensing** — choose open-source vs proprietary for the codebase and add a `LICENSE` file. Currently the repository has **no license file**, which means default "all rights reserved" applies.

## Regenerating the website

```powershell
python tools/build_site.py
```

The generator writes 11 static HTML pages plus `robots.txt`, `sitemap.xml` and `.nojekyll` into `site/`. It uses relative paths so the site works under the `/kalla-lai/` subpath on GitHub Pages and also from a plain local static server.

For a local preview that mirrors the Pages subpath:

```powershell
python -m http.server 8000 --directory site
# then open http://localhost:8000/index.html
```

## Deploy

`.github/workflows/deploy-pages.yml` publishes the `site/` directory (including the built Flutter app under `site/app/`) on every push to `master`. No CI build step is required — the site is plain static files, which keeps deployments fast and deterministic.
