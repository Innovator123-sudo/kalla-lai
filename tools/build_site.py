"""Generate the static Kalla-Lai startup website into site/.

Everything is plain HTML/CSS/JS so GitHub Pages serves it without a build step.
Run:  python tools/build_site.py
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "site"
OUT.mkdir(parents=True, exist_ok=True)

REPO = "https://github.com/Innovator123-sudo/kalla-lai"
APP = "app/"
LIVE_API = "https://kalla-lai-api.vercel.app"

# --------------------------------------------------------------------------
# Inline icon set (stroke based, inherits currentColor)
# --------------------------------------------------------------------------
_PATHS = {
    "shield": '<path d="M12 3 4.5 6v5.4c0 4.6 3.1 8.3 7.5 9.6 4.4-1.3 7.5-5 7.5-9.6V6L12 3Z"/><path d="m9 12 2 2 4-4"/>',
    "search": '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.6-3.6"/>',
    "calendar": '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/>',
    "wallet": '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10h18M16 15h2"/>',
    "star": '<path d="m12 3 2.7 5.5 6 .9-4.3 4.2 1 6-5.4-2.8-5.4 2.8 1-6L3.3 9.4l6-.9L12 3Z"/>',
    "users": '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5"/><path d="M16 5.2a3.2 3.2 0 0 1 0 6.1M18 14.8c2 .7 3 2.5 3 5.2"/>',
    "briefcase": '<rect x="3" y="7" width="18" height="13" rx="3"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 12h18"/>',
    "check": '<path d="m4 12 5 5L20 6"/>',
    "lock": '<rect x="4" y="10" width="16" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    "bolt": '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 2.5 4 5.6 4 9s-1.4 6.5-4 9c-2.6-2.5-4-5.6-4-9s1.4-6.5 4-9Z"/>',
    "chart": '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    "heart": '<path d="M20.5 8.5c0 4.4-8.5 10-8.5 10s-8.5-5.6-8.5-10a4.5 4.5 0 0 1 8.5-2 4.5 4.5 0 0 1 8.5 2Z"/>',
    "code": '<path d="m8 8-4 4 4 4M16 8l4 4-4 4M14 4l-4 16"/>',
    "pin": '<path d="M12 21s7-5.6 7-11a7 7 0 1 0-14 0c0 5.4 7 11 7 11Z"/><circle cx="12" cy="10" r="2.5"/>',
    "bell": '<path d="M18 9a6 6 0 1 0-12 0c0 6-2 7-2 7h16s-2-1-2-7ZM10 20a2 2 0 0 0 4 0"/>',
    "spark": '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M18.4 5.6l-2.8 2.8M8.4 15.6l-2.8 2.8"/>',
    "layers": '<path d="m12 3 9 5-9 5-9-5 9-5ZM3 13l9 5 9-5M3 17l9 5 9-5"/>',
    "message": '<path d="M20 15a3 3 0 0 1-3 3H8l-4 3V6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v9Z"/>',
}


def icon(name: str, cls: str = "card__icon") -> str:
    return (
        f'<div class="{cls}"><svg viewBox="0 0 24 24" aria-hidden="true">'
        f"{_PATHS[name]}</svg></div>"
    )


def card(icon_name: str, title: str, text: str, tone: str = "") -> str:
    tone_cls = f" card__icon--{tone}" if tone else ""
    return (
        '<div class="card reveal">'
        + icon(icon_name, "card__icon" + tone_cls)
        + f"<h3>{title}</h3><p>{text}</p></div>"
    )


# --------------------------------------------------------------------------
# Shared shell
# --------------------------------------------------------------------------
HEAD = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}}</title>
<meta name="description" content="{{DESC}}">
<meta name="theme-color" content="#101a3a">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Kalla-Lai">
<meta property="og:title" content="{{TITLE}}">
<meta property="og:description" content="{{DESC}}">
<meta property="og:image" content="assets/img/og-cover.svg">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/png" href="assets/img/favicon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Noto+Sans+Devanagari:wght@600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/css/styles.css">
<script>
document.documentElement.classList.add('js');
/* If the main script never boots, reveal every element anyway. */
setTimeout(function () {
  if (!window.__kallaLaiBooted) document.documentElement.classList.remove('js');
}, 2000);
</script>
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Organization","name":"Kalla-Lai","alternateName":"कल्ला-लाई","url":"https://innovator123-sudo.github.io/kalla-lai/","logo":"https://innovator123-sudo.github.io/kalla-lai/assets/img/kalla_lai_logo.png","description":"A trusted two-sided work marketplace connecting verified independent workers with employers.","sameAs":["__REPO__"]}
</script>
{{EXTRA_HEAD}}
</head>
<body>
<a class="skip-link" href="#main">Skip to content</a>
{{BODY}}
<script src="assets/js/main.js"></script>
{{EXTRA_SCRIPT}}
</body>
</html>
""".replace("__REPO__", REPO)


def nav(active: str = "") -> str:
    links = [
        ("Product", "index.html#product"),
        ("How it works", "index.html#how"),
        ("For workers", "index.html#audiences"),
        ("Trust & safety", "trust.html"),
        ("Roadmap", "roadmap.html"),
        ("Investors", "investors.html"),
        ("About", "about.html"),
    ]
    items = "".join(
        f'<a href="{href}"'
        + (' aria-current="page"' if key == active else "")
        + f">{label}</a>"
        for key, label, href in [(k, k, h) for k, h in links]
    )
    return f"""<header class="site-header">
  <div class="container nav">
    <a class="brand" href="index.html" aria-label="Kalla-Lai home">
      <img src="assets/img/kalla_lai_logo.png" alt="Kalla-Lai" width="150" height="40">
    </a>
    <nav class="nav__links" aria-label="Main navigation">{items}</nav>
    <div class="nav__actions">
      <a class="btn btn--primary btn--sm" href="{APP}">Launch the app <span class="arrow">→</span></a>
    </div>
    <button class="nav__toggle" type="button" aria-label="Open menu" aria-expanded="false" aria-controls="primary-nav"><span></span></button>
  </div>
</header>"""


def footer() -> str:
    return f"""<footer class="site-footer">
  <div class="container">
    <div class="footer__grid">
      <div class="footer__brand">
        <img src="assets/img/kalla_lai_logo_white.png" alt="Kalla-Lai">
        <p>Work, verified. A trusted marketplace where independent workers and employers find each other, agree on the shift, and get paid with confidence.</p>
        <p style="margin-top:16px"><a class="btn btn--amber btn--sm" href="{APP}">Open the app <span class="arrow">→</span></a></p>
      </div>
      <div>
        <h4>Product</h4>
        <ul class="footer__links">
          <li><a href="index.html#product">Platform</a></li>
          <li><a href="index.html#audiences">For workers</a></li>
          <li><a href="index.html#audiences">For employers</a></li>
          <li><a href="index.html#how">How it works</a></li>
          <li><a href="roadmap.html">Roadmap</a></li>
        </ul>
      </div>
      <div>
        <h4>Company</h4>
        <ul class="footer__links">
          <li><a href="about.html">About & mission</a></li>
          <li><a href="investors.html">Investors & partners</a></li>
          <li><a href="pitch.html">Pitch deck</a></li>
          <li><a href="faq.html">FAQ</a></li>
          <li><a href="contact.html">Contact</a></li>
        </ul>
      </div>
      <div>
        <h4>Resources</h4>
        <ul class="footer__links">
          <li><a href="{REPO}">GitHub repository</a></li>
          <li><a href="{REPO}/blob/master/README.md">Developer docs</a></li>
          <li><a href="{REPO}/blob/master/startup/README.md">Startup kit</a></li>
          <li><a href="trust.html">Trust & safety</a></li>
          <li><a href="privacy.html">Privacy</a></li>
          <li><a href="terms.html">Terms</a></li>
        </ul>
      </div>
    </div>
    <div class="footer__bottom">
      <span>© <span data-year>2026</span> Kalla-Lai (कल्ला-लाई). Built in Nepal, for the way work actually happens.</span>
      <span>Early-stage product · <a href="{REPO}" style="color:#c9cff0">Open documentation</a></span>
    </div>
  </div>
</footer>"""


def page(
    filename: str,
    title: str,
    description: str,
    body: str,
    active: str = "",
    extra_head: str = "",
    extra_script: str = "",
) -> None:
    html = (
        HEAD.replace("{{TITLE}}", title)
        .replace("{{DESC}}", description)
        .replace("{{EXTRA_HEAD}}", extra_head)
        .replace("{{EXTRA_SCRIPT}}", extra_script)
        .replace("{{BODY}}", nav(active) + body + footer())
    )
    (OUT / filename).write_text(html, encoding="utf-8")
    print("wrote", filename)


def section_head(eyebrow: str, title: str, text: str = "", center: bool = False) -> str:
    c = " section-head--center" if center else ""
    return (
        f'<div class="section-head{c} reveal">'
        f'<span class="eyebrow">{eyebrow}</span><h2>{title}</h2>'
        + (f"<p>{text}</p>" if text else "")
        + "</div>"
    )


def phone_markup() -> str:
    return """<div class="phone" aria-hidden="true">
  <div class="phone__screen">
    <div class="phone__notch"></div>
    <div class="phone__body">
      <img class="phone__logo" src="assets/img/kalla_lai_logo.png" alt="">
      <div class="phone__hello">Good morning, Sita</div>
      <div class="phone__sub">3 verified shifts near you</div>
      <div class="mock-card"><div class="mock-avatar"></div><div class="mock-lines"><div class="mock-line"></div><div class="mock-line mock-line--short"></div></div><span class="mock-badge">VERIFIED</span></div>
      <div class="mock-card"><div class="mock-avatar" style="background:linear-gradient(135deg,#f5a623,#ffcb70)"></div><div class="mock-lines"><div class="mock-line"></div><div class="mock-line mock-line--short"></div></div></div>
      <div class="mock-card"><div class="mock-avatar" style="background:linear-gradient(135deg,#16a34a,#86efac)"></div><div class="mock-lines"><div class="mock-line"></div><div class="mock-line mock-line--tiny"></div></div></div>
      <div class="mock-cta">Find work nearby</div>
    </div>
    <div class="phone__tabbar"><span class="phone__tab"></span><span class="phone__tab"></span><span class="phone__tab"></span><span class="phone__tab"></span></div>
  </div>
</div>"""


# --------------------------------------------------------------------------
# 1. Landing page
# --------------------------------------------------------------------------
features = [
    ("shield", "Verified identities", "Document, selfie and liveness checks through a hosted KYC provider. The platform never stores identity photos or face templates.", ""),
    ("pin", "Nearby discovery", "Workers find shifts by area; employers see suitable, verified people close to where the work actually is.", "amber"),
    ("calendar", "Shift coordination", "Dispatch, attendance and completion states keep both sides on the same page from agreement to sign-off.", ""),
    ("wallet", "Payment you can trace", "An escrow-style ledger records what was agreed, what was approved and what was settled — before any money is claimed.", "green"),
    ("star", "Portable reputation", "Completed work builds a profile with ratings, portfolios and work history that travels with the worker.", ""),
    ("briefcase", "Hiring requisitions", "Employers post structured requests, review applicants and manage the whole engagement in one place.", "amber"),
    ("bell", "Clear status, every step", "Role-aware notifications and honest state labels: the UI never claims verification or payment before a system confirms it.", ""),
    ("layers", "Two modes, one account", "Switch between finding work and hiring without losing your profile, history or trust signals.", "green"),
]

faq_items = [
    ("What is Kalla-Lai?", "A two-sided work marketplace for independent service providers and the people who hire them. It brings verification, discovery, shift coordination, reputation and payment tracking into one place instead of leaving them to phone calls and chat groups."),
    ("Is it live and can I use it today?", "There is a working web app you can open from this site. It is an early-stage public build connected to a live backend; it is not yet a production-grade service with regulated payments or full KYC coverage. Expect rough edges."),
    ("Who is it for?", "Two groups: workers who want a steady, trustworthy way to find and be paid for shifts, and employers — households and businesses — who need verified help without the uncertainty of informal hiring."),
    ("How does verification work?", "A hosted identity provider performs document OCR, selfie comparison and liveness checks. Only a session reference, consent record and decision state are stored by the platform — not document images or biometric templates. Verification is only reflected in the app after a signed provider webhook confirms approval."),
    ("Does Kalla-Lai hold or move money?", "Not in the current build. The app models an escrow-style ledger and clear payment states; real settlement requires a licensed payment provider and is on the roadmap. The UI is deliberately designed never to claim money moved unless a provider confirms it."),
    ("Is the code open?", "Yes — the full Flutter client, Node/TypeScript API, database migrations and the architecture, workflow, security and QA documentation are in the public GitHub repository."),
    ("Can I invest or partner?", "We welcome conversations with early-stage investors, employer pilots and identity/payment infrastructure partners. See the investor brief and get in touch."),
]


def faq_markup(items, limit=None):
    rows = []
    for i, (q, a) in enumerate(items[:limit] if limit else items):
        rows.append(
            f'<div class="accordion__item"><button class="accordion__trigger" type="button" '
            f'aria-expanded="false" aria-controls="faq-{i}">{q}</button>'
            f'<div class="accordion__content" id="faq-{i}" hidden><p>{a}</p></div></div>'
        )
    return '<div class="accordion">' + "".join(rows) + "</div>"


index_body = f"""<main id="main">
<section class="hero">
  <div class="container hero__grid">
    <div>
      <span class="pill"><span class="pill__dot"></span> Now in public beta · Nepal-first</span>
      <h1>Work, <span class="accent">verified.</span><br>Found nearby. Paid with confidence.</h1>
      <p class="hero__lead">Kalla-Lai (कल्ला-लाई) connects independent workers with the people who need them — with real identity checks, clear shift agreements and a payment trail both sides can trust.</p>
      <div class="btn-row">
        <a class="btn btn--primary" href="{APP}">Launch the app <span class="arrow">→</span></a>
        <a class="btn btn--ghost" href="pitch.html">See the pitch <span class="arrow">↗</span></a>
      </div>
      <p class="hero__note">No install needed · Works in your browser · Open-source codebase</p>
    </div>
    <div class="hero__visual">
      <div class="hero__blob"></div>
      <div class="float-card float-card--top"><span class="float-card__icon float-card__icon--green">✓</span> Identity verified</div>
      {phone_markup()}
      <div class="float-card float-card--bottom"><span class="float-card__icon float-card__icon--amber">₨</span> Shift settlement recorded</div>
    </div>
  </div>
</section>

<div class="trust-strip">
  <div class="container trust-strip__inner">
    <span class="trust-item"><span class="trust-item__check">✓</span> Verified identities</span>
    <span class="trust-item"><span class="trust-item__check">✓</span> Escrow-style payment trail</span>
    <span class="trust-item"><span class="trust-item__check">✓</span> Area-based discovery</span>
    <span class="trust-item"><span class="trust-item__check">✓</span> Portable worker reputation</span>
    <span class="trust-item"><span class="trust-item__check">✓</span> Privacy by design</span>
  </div>
</div>

<section class="section" id="problem">
  <div class="container">
    {section_head("The problem", "Good work still runs on promises.", "Millions of everyday jobs are found through word of mouth, arranged over chat, and settled in cash. Nobody involved has a reliable way to know who they are dealing with, what was agreed, or when they will be paid.", True)}
    <div class="grid grid--3">
      <div class="card problem-card reveal">{icon('users')}<h3>For workers</h3><p>No portable proof of skill or reliability. Every new engagement starts from zero, and a completed shift is no guarantee of payment.</p></div>
      <div class="card problem-card reveal">{icon('briefcase')}<h3>For employers</h3><p>No dependable way to check who is arriving, whether they can do the job, or how to resolve it when a shift goes wrong.</p></div>
      <div class="card problem-card reveal">{icon('message')}<h3>For everyone</h3><p>Everything lives in scattered messages. There is no shared record of the agreement, the attendance, the completion or the settlement.</p></div>
    </div>
  </div>
</section>

<section class="section section--tint" id="product">
  <div class="container">
    {section_head("The platform", "One trusted layer between work and the people who do it.", "Kalla-Lai turns an informal transaction into a clear, observable journey — from a verified profile to a settled shift.", True)}
    <div class="platform">
      <div class="platform__side"><span class="emoji">👷</span><strong>Workers</strong><span>Profile · verification · discovery · shifts · reputation</span></div>
      <div class="platform__core">
        <img src="assets/img/kalla_lai_logo_white.png" alt="Kalla-Lai">
        <div class="platform__chips"><span>Identity</span><span>Matching</span><span>Dispatch</span><span>Escrow ledger</span><span>Reputation</span><span>Disputes</span></div>
        <span style="font-size:.78rem;color:#c3cbe9">Flutter client · Node/TypeScript API · Supabase Postgres</span>
      </div>
      <div class="platform__side"><span class="emoji">🏢</span><strong>Employers</strong><span>Requisitions · review · attendance · settlement · history</span></div>
    </div>
    <div class="grid grid--4" style="margin-top:34px">
      {''.join(card(i, t, d, tone) for i, t, d, tone in features)}
    </div>
  </div>
</section>

<section class="section" id="audiences">
  <div class="container">
    {section_head("Built for both sides", "Two very different jobs. One shared source of truth.", "Switch the view to see what each side gets out of the same marketplace.")}
    <div class="tabs" role="tablist" aria-label="Audience">
      <button class="tab" role="tab" aria-selected="true" data-target="panel-workers">I'm looking for work</button>
      <button class="tab" role="tab" aria-selected="false" data-target="panel-employers">I'm hiring</button>
    </div>
    <div class="tab-panel" id="panel-workers" role="tabpanel">
      <div class="tab-panel__grid">
        <div>
          <h3 style="font-size:1.5rem;margin-bottom:16px">Stop starting from zero.</h3>
          <ul class="feature-list">
            <li><span class="feature-list__icon">✓</span><span><strong>One profile that compounds</strong><span>Skills, area, languages, portfolio and promo video — all in one place.</span></span></li>
            <li><span class="feature-list__icon">✓</span><span><strong>Verified once, trusted everywhere</strong><span>Complete a hosted identity check and carry the badge across shifts.</span></span></li>
            <li><span class="feature-list__icon">✓</span><span><strong>Find work close to you</strong><span>Area-based discovery with clear requirements before you apply.</span></span></li>
            <li><span class="feature-list__icon">✓</span><span><strong>Know where your money stands</strong><span>Shift, attendance, completion and settlement states are visible end to end.</span></span></li>
          </ul>
          <a class="btn btn--primary" href="{APP}">Create a worker profile <span class="arrow">→</span></a>
        </div>
        <div class="visual-panel">{phone_markup()}</div>
      </div>
    </div>
    <div class="tab-panel" id="panel-employers" role="tabpanel" hidden>
      <div class="tab-panel__grid">
        <div>
          <h3 style="font-size:1.5rem;margin-bottom:16px">Hire with fewer unknowns.</h3>
          <ul class="feature-list">
            <li><span class="feature-list__icon">✓</span><span><strong>Structured requisitions</strong><span>Describe the shift, the skills, the time and the rate once — then review suitable people.</span></span></li>
            <li><span class="feature-list__icon">✓</span><span><strong>Verification you can rely on</strong><span>See who has completed an approved identity check before they arrive.</span></span></li>
            <li><span class="feature-list__icon">✓</span><span><strong>Rich company profile</strong><span>Logo, bio, service categories, portfolio and contact details build trust back.</span></span></li>
            <li><span class="feature-list__icon">✓</span><span><strong>One record of the engagement</strong><span>Dispatch, attendance, completion, review and dispute in a single trail.</span></span></li>
          </ul>
          <a class="btn btn--primary" href="{APP}">Post a requisition <span class="arrow">→</span></a>
        </div>
        <div class="visual-panel" style="background:linear-gradient(150deg,#fff6e6,#f2efff)">{phone_markup()}</div>
      </div>
    </div>
  </div>
</section>

<section class="section section--tint" id="how">
  <div class="container">
    {section_head("How it works", "From profile to paid shift in four clear steps.")}
    <div class="grid grid--2" style="gap:48px;align-items:start">
      <div class="steps">
        <div class="step reveal"><h3>Create a real profile</h3><p>Sign up with email or Google, choose worker or employer, and add the details that matter — skills, area, portfolio or company information.</p></div>
        <div class="step reveal"><h3>Get verified</h3><p>Complete onboarding and a hosted document + selfie check. Only the decision state and consent record are stored by Kalla-Lai; a signed webhook unlocks the marketplace.</p></div>
        <div class="step reveal"><h3>Match and agree</h3><p>Workers discover nearby shifts; employers post requisitions and review applicants. Both sides see the same terms before a shift starts.</p></div>
        <div class="step reveal"><h3>Complete and settle</h3><p>Attendance, completion and review are recorded. The escrow-style ledger shows exactly what was agreed and what was paid — with a dispute path when something goes wrong.</p></div>
      </div>
      <div class="card card--plain reveal" style="padding:34px;background:linear-gradient(160deg,#fff,#f7f8fd)">
        <span class="eyebrow">Design principle</span>
        <h3 style="font-size:1.5rem;margin-bottom:14px">Never claim what the system hasn't confirmed.</h3>
        <p>The UI is deliberately honest: no "verified" badge without an approved provider decision, no "paid" label without a confirmed settlement, no "published" job without a persisted requisition. Trust is a product feature, not a marketing claim.</p>
        <a href="trust.html" style="font-weight:700">Read the trust & safety approach <span class="arrow">→</span></a>
      </div>
    </div>
  </div>
</section>

<section class="section section--navy" id="trust">
  <div class="container">
    {section_head("Trust & safety", "The part we refuse to shortcut.", "A marketplace only works if both sides believe the record. These are the controls designed into the product and the API — not a checklist for later.", True)}
    <div class="grid grid--3">
      <div class="card reveal" style="background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.14)">{icon('lock')}<h3 style="color:#fff">Identity by a specialist</h3><p>Document OCR, selfie comparison and liveness run in a hosted KYC provider. Kalla-Lai stores no identity images, face templates or OCR data.</p></div>
      <div class="card reveal" style="background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.14)">{icon('code')}<h3 style="color:#fff">Signed, verified state changes</h3><p>Verification decisions arrive through an HMAC-signed webhook; role-based access and idempotent API calls keep records consistent.</p></div>
      <div class="card reveal" style="background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.14)">{icon('chart')}<h3 style="color:#fff">An auditable money trail</h3><p>An escrow-style ledger separates agreed, approved and settled amounts, with review and dispute states for disagreements.</p></div>
    </div>
    <p style="text-align:center;margin-top:34px"><a class="btn btn--outline-light" href="trust.html">Full trust & safety detail <span class="arrow">→</span></a></p>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="grid grid--2" style="align-items:center;gap:56px">
      <div class="visual-panel" style="background:linear-gradient(150deg,#eef0ff,#fff6e6)">{phone_markup()}</div>
      <div>
        <span class="eyebrow">Try it now</span>
        <h2>A real product, not a mockup.</h2>
        <p class="lead" style="margin:16px 0 24px">The app on this site is the working Flutter web client, backed by a live Node/TypeScript API and Supabase Postgres. Browse the flows, create an account, and see how the states behave.</p>
        <ul class="feature-list">
          <li><span class="feature-list__icon">✓</span><span><strong>Email & Google sign-in</strong><span>Persisted sessions so you stay signed in.</span></span></li>
          <li><span class="feature-list__icon">✓</span><span><strong>Settings & configuration</strong><span>Theme, language, notifications and API endpoint.</span></span></li>
          <li><span class="feature-list__icon">✓</span><span><strong>Open documentation</strong><span>Architecture, workflows, security, privacy and QA docs in the repo.</span></span></li>
        </ul>
        <div class="btn-row" style="margin-top:26px">
          <a class="btn btn--primary" href="{APP}">Launch the app <span class="arrow">→</span></a>
          <a class="btn btn--ghost" href="{REPO}">View the code</a>
        </div>
      </div>
    </div>
  </div>
</section>

<section class="section section--tint" id="opportunity">
  <div class="container">
    {section_head("Why now", "The infrastructure is finally affordable.", "Three shifts make a trusted local work marketplace practical today in a way it wasn't a decade ago.", True)}
    <div class="grid grid--3">
      {card('globe', 'Smartphones are universal', 'Workers and employers already carry the device, the camera and the connectivity needed for discovery and verification.', '')}
      {card('shield', 'KYC is an API, not a branch', 'Hosted identity providers make document and liveness checks available to small teams without building a compliance stack.', 'amber')}
      {card('bolt', 'Digital settlement is normal', 'Expectations around instant, traceable payment are set. The remaining gap is a trusted record of the work itself.', 'green')}
    </div>
    <div class="callout" style="max-width:820px;margin:38px auto 0">
      <strong>Our thesis</strong>
      <p>The winner in local work won't be the biggest job board — it will be the layer both sides trust enough to settle through. That means verification, a shared agreement and an auditable payment trail, designed together from day one.</p>
    </div>
  </div>
</section>

<section class="section" id="roadmap">
  <div class="container">
    {section_head("Roadmap", "Honest about where we are.", "We publish the plan with real status labels so partners know what exists today and what is still being built.")}
    <div class="roadmap">
      <div class="roadmap__item reveal"><div class="roadmap__phase"><span class="chip chip--now">● Built</span><strong style="color:var(--muted);font-size:.82rem">Today</strong></div><div><h3>Working end-to-end product</h3><ul><li>Flutter web client with worker and employer modes, profiles, discovery, requisitions and shift flows</li><li>Node/TypeScript API with role-based access, migrations and Supabase Postgres</li><li>Hosted identity-verification integration path and escrow-style ledger model</li><li>Full architecture, workflow, security/privacy and QA documentation, open in the repo</li></ul></div></div>
      <div class="roadmap__item reveal"><div class="roadmap__phase"><span class="chip chip--next">◐ In progress</span><strong style="color:var(--muted);font-size:.82rem">Next</strong></div><div><h3>Production hardening & pilots</h3><ul><li>Licensed payment settlement and payout rails with a real provider</li><li>Full KYC coverage, consent and retention review for launch markets</li><li>Employer pilots to validate supply density, repeat hiring and unit economics</li><li>Mobile builds, push notifications and offline-friendly field flows</li></ul></div></div>
      <div class="roadmap__item reveal"><div class="roadmap__phase"><span class="chip chip--later">○ Planned</span><strong style="color:var(--muted);font-size:.82rem">Later</strong></div><div><h3>Scale the trust layer</h3><ul><li>Reputation scoring, dispute resolution SLAs and insurance partnerships</li><li>Category expansion and multi-city operations</li><li>Employer tooling: bulk shifts, invoicing and workforce analytics</li></ul></div></div>
    </div>
    <p style="margin-top:26px"><a class="btn btn--ghost" href="roadmap.html">Full roadmap <span class="arrow">→</span></a></p>
  </div>
</section>

<section class="section section--tint">
  <div class="container">
    <div class="grid grid--2" style="align-items:center;gap:56px">
      <div>
        <span class="eyebrow">Investors & partners</span>
        <h2>We're building the trust layer for everyday work.</h2>
        <p class="lead" style="margin:16px 0 24px">Early-stage, product-first and openly documented. We're looking for employer pilot partners, identity and payment infrastructure partners, and investors who understand marketplaces at the bottom of the pyramid.</p>
        <div class="btn-row">
          <a class="btn btn--primary" href="investors.html">Read the investor brief <span class="arrow">→</span></a>
          <a class="btn btn--ghost" href="contact.html">Get in touch</a>
        </div>
      </div>
      <div class="card reveal" style="padding:34px">
        <span class="eyebrow">What we can show you</span>
        <ul class="feature-list" style="margin-bottom:0">
          <li><span class="feature-list__icon">✓</span><span><strong>A working product</strong><span>Not a pitch-only concept — open the app from this site.</span></span></li>
          <li><span class="feature-list__icon">✓</span><span><strong>Open technical documentation</strong><span>Architecture, data, API, security and QA decisions written down.</span></span></li>
          <li><span class="feature-list__icon">✓</span><span><strong>A clear, staged plan</strong><span>Roadmap and risk register in the startup kit.</span></span></li>
          <li><span class="feature-list__icon">✓</span><span><strong>Honest gaps</strong><span>Payments, regulated KYC and legal review are named as open items.</span></span></li>
        </ul>
      </div>
    </div>
  </div>
</section>

<section class="section">
  <div class="container">
    {section_head("Questions", "The short version.", "Everything else is in the FAQ.", True)}
    <div style="max-width:820px;margin:0 auto">{faq_markup(faq_items[:4])}</div>
    <p style="text-align:center;margin-top:28px"><a class="btn btn--ghost" href="faq.html">All questions <span class="arrow">→</span></a></p>
  </div>
</section>

<section class="section" style="padding-top:0">
  <div class="container">
    <div class="cta reveal">
      <h2>Better work starts with a handshake you can verify.</h2>
      <p>Open the app, explore the marketplace, or read the plan. Everything we have is on the table.</p>
      <div class="btn-row" style="justify-content:center">
        <a class="btn btn--amber" href="{APP}">Launch the app <span class="arrow">→</span></a>
        <a class="btn btn--outline-light" href="{REPO}">Explore the repository</a>
      </div>
    </div>
  </div>
</section>
</main>"""

page("index.html", "Kalla-Lai — Work, verified.", "Kalla-Lai (कल्ला-लाई) is a trusted two-sided work marketplace connecting verified independent workers with employers through identity checks, nearby discovery, shift coordination and an auditable payment trail.", index_body, "Product")

# --------------------------------------------------------------------------
# 2. About
# --------------------------------------------------------------------------
about_body = """<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / About</div>
  <span class="eyebrow">About us</span>
  <h1>Work deserves better infrastructure.</h1>
  <p>Kalla-Lai is an early-stage product company building the trust layer for everyday, local work — starting in Nepal, starting with the shifts that never make it onto a job board.</p>
</div></section>

<section class="section"><div class="container prose">
  <h2>The story</h2>
  <p>Most work in our communities is found through someone who knows someone. A phone call, a chat message, a cash payment at the end of the day. It is fast, human and deeply local — and it leaves everyone exposed. A worker has no proof of reliability beyond the last person who hired them. An employer has no way to check who is coming to their home or site. When something goes wrong, there is no record to point to.</p>
  <p>We started Kalla-Lai because the tools that fixed this for software freelancers and ride-hailing never reached the everyday service economy. The ingredients now exist — a smartphone in every pocket, identity verification as an API, and digital payments people already trust. What was missing was a single layer that joins them into one understandable journey for both sides.</p>

  <h2>Our mission</h2>
  <div class="callout"><strong>Make trusted work accessible to everyone.</strong><p>Every completed shift should leave both people better off — and leave behind a record that makes the next one easier, safer and faster.</p></div>

  <h2>How we build</h2>
  <div class="grid grid--2" style="margin:22px 0">
    <div class="card"><h3>Honesty over polish</h3><p>The app never shows "verified", "paid" or "published" unless an authoritative service confirms it. A pretty screen that lies is worse than a plain one that tells the truth.</p></div>
    <div class="card"><h3>Privacy by design</h3><p>Identity checks happen with a specialist provider. We keep a session reference, consent record and decision — not your documents, face templates or home address.</p></div>
    <div class="card"><h3>Open by default</h3><p>Architecture, workflow, security, privacy and QA decisions are documented in the public repository. Trust is easier when the reasoning is visible.</p></div>
    <div class="card"><h3>Both sides, always</h3><p>A marketplace that only serves one side breaks. Worker reputation and employer credibility are designed together.</p></div>
  </div>

  <h2>Where we are</h2>
  <p>Kalla-Lai is an early-stage, product-first venture. There is a working web client, a live API, real database migrations and a documented integration path for identity verification. Regulated payment settlement, full KYC coverage for launch markets, legal review and mobile release are open items — see the <a href="roadmap.html">roadmap</a> and <a href="investors.html">investor brief</a> for the unvarnished version.</p>

  <div class="callout callout--amber"><strong>Join us</strong><p>We're interested in founding-engineer profiles, marketplace operators, employer pilot partners and design help with local-language accessibility. If that sounds like you, <a href="contact.html">get in touch</a>.</p></div>
</div></section>
</main>"""
page("about.html", "About — Kalla-Lai", "Why Kalla-Lai exists, our mission, how we build, and where the company is today.", about_body, "About")

# --------------------------------------------------------------------------
# 3. Investors
# --------------------------------------------------------------------------
investors_body = """<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Investors & partners</div>
  <span class="eyebrow">Investor brief</span>
  <h1>The trust layer for everyday work.</h1>
  <p>An early-stage, openly documented marketplace for verified local work. Here is the thesis, what exists, what doesn't, and the conversations we want to have.</p>
  <div class="btn-row" style="margin-top:26px">
    <a class="btn btn--primary" href="pitch.html">Open the pitch deck <span class="arrow">→</span></a>
    <a class="btn btn--ghost" href="contact.html">Start a conversation</a>
  </div>
</div></section>

<section class="section"><div class="container">
  <div class="grid grid--2" style="gap:56px;align-items:start">
    <div class="prose">
      <h2 style="margin-top:0">The thesis</h2>
      <p>Informal local work is enormous, recurring and almost entirely unbundled. Discovery happens by word of mouth, agreements live in chat, and settlement happens in cash. Each side carries the whole risk of the other side being unknown.</p>
      <p>Job boards attacked discovery and stopped. They optimised for posting volume, not for whether the person showed up, the work was completed, or the payment was right. We think the durable business is the <strong>transaction layer</strong> — the thing both parties trust enough to settle through.</p>
      <div class="callout"><strong>Why we can build it now</strong><p>Smartphone penetration, hosted KYC as an API, and normalised digital settlement collapsed the cost of a trusted marketplace. The remaining work is product and operational, not fundamental infrastructure.</p></div>
      <h2>The wedge</h2>
      <p>Start with a narrow, high-frequency category and one geography where shift-based work repeats. Verification and a shared agreement create immediate value on the very first job; reputation and payment history make the second job cheaper and the tenth job nearly frictionless. Repetition is the moat — not the listing.</p>
      <h2>Business model</h2>
      <p>The natural model is a transparent service or transaction fee on settled shifts, with optional employer tooling (bulk shifts, invoicing, workforce analytics) as a later subscription layer. Exact pricing is a pilot question, not a deck assumption. Unit economics depend on repeat hiring frequency and settlement take-rate — both are the metrics we would design a pilot to measure.</p>
    </div>
    <div>
      <div class="card reveal" style="margin-bottom:20px">
        <span class="eyebrow">Stage</span>
        <h3 style="font-size:1.35rem">Pre-seed · product built</h3>
        <ul class="card__list">
          <li>Working Flutter web client in public beta</li>
          <li>Live Node/TypeScript API + Supabase Postgres</li>
          <li>Hosted KYC integration path designed and documented</li>
          <li>Escrow-style ledger model with review and dispute states</li>
          <li>Open architecture, security, privacy and QA documentation</li>
        </ul>
      </div>
      <div class="card reveal" style="margin-bottom:20px">
        <span class="eyebrow">Open risks — stated plainly</span>
        <ul class="card__list">
          <li>Licensed payment settlement not yet live</li>
          <li>KYC coverage and consent review needed per launch market</li>
          <li>Supply density and repeat-hire rate unproven at scale</li>
          <li>Legal, labour and tax review outstanding</li>
          <li>Mobile release and field-mode reliability still ahead</li>
        </ul>
      </div>
      <div class="card reveal">
        <span class="eyebrow">What we're looking for</span>
        <ul class="card__list">
          <li>Employer pilot partners with recurring shift demand</li>
          <li>Identity, payment and insurance infrastructure partners</li>
          <li>Early-stage investors with marketplace operational experience</li>
          <li>Introductions to local regulators and labour experts</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="callout callout--amber" style="max-width:900px;margin:44px auto 0"><strong>A note on numbers</strong><p>This brief deliberately contains no invented traction metrics, market-size figures or fundraising targets. We will share measured pilot data as it exists. If you'd like the underlying plan, the <a href="https://github.com/Innovator123-sudo/kalla-lai/blob/master/startup/README.md">startup kit in the repository</a> lays out the model, assumptions, KPIs and risk register for review.</p></div>
</div></section>

<section class="section section--tint"><div class="container">
  <div class="cta" style="background:linear-gradient(120deg,#101a3a,#5b4bd6)">
    <h2>Let's talk about the pilot, not the pitch.</h2>
    <p>Bring us a real shift-based hiring problem and we'll show you exactly what the product does today — and where it still falls short.</p>
    <div class="btn-row" style="justify-content:center"><a class="btn btn--amber" href="contact.html">Get in touch <span class="arrow">→</span></a><a class="btn btn--outline-light" href="pitch.html">View the deck</a></div>
  </div>
</div></section>
</main>"""
page("investors.html", "Investors & partners — Kalla-Lai", "The Kalla-Lai investment thesis, stage, open risks, business model and the partnerships we are looking for.", investors_body, "Investors")

# --------------------------------------------------------------------------
# 4. Roadmap
# --------------------------------------------------------------------------
roadmap_body = """<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Roadmap</div>
  <span class="eyebrow">Roadmap</span>
  <h1>What exists, what's next, what's still an idea.</h1>
  <p>Published with real status labels. If a capability is not live, it isn't described as live.</p>
</div></section>

<section class="section"><div class="container">
  <div class="roadmap">
    <div class="roadmap__item"><div class="roadmap__phase"><span class="chip chip--now">● Shipped</span><strong style="color:var(--muted);font-size:.82rem">Phase 1</strong></div><div>
      <h3>Client & core marketplace</h3>
      <ul><li>Flutter web client with animated intro, worker/employer journey and settings</li><li>Email/password and Google sign-in with persisted sessions</li><li>Worker profile with skills, area, languages, portfolio and promo media</li><li>Employer profile with company info, categories, portfolio and contact details</li><li>Vacancy discovery, hiring requisitions, shift and escrow-ledger states</li><li>Admin people console with staff profile editing</li></ul>
    </div></div>
    <div class="roadmap__item"><div class="roadmap__phase"><span class="chip chip--now">● Shipped</span><strong style="color:var(--muted);font-size:.82rem">Phase 1</strong></div><div>
      <h3>Backend & trust foundations</h3>
      <ul><li>Node/TypeScript API with role-based access, idempotency and structured errors</li><li>Supabase Postgres with versioned migrations applied on startup</li><li>Hosted identity verification (document OCR, selfie, liveness) with HMAC-signed decision webhook</li><li>Privacy-by-design storage: decision state and consent record only, no identity images</li><li>Open documentation: architecture, workflows, data, API/realtime, security/privacy, UI/UX & QA</li></ul>
    </div></div>
    <div class="roadmap__item"><div class="roadmap__phase"><span class="chip chip--next">◐ In progress</span><strong style="color:var(--muted);font-size:.82rem">Phase 2</strong></div><div>
      <h3>Production hardening</h3>
      <ul><li>Licensed payment provider for real settlement and payouts</li><li>KYC coverage, consent versioning and retention/deletion policy per launch market</li><li>Production secrets, CORS allow-list, rate limiting and observability</li><li>End-to-end test coverage for verification, dispute and settlement paths</li><li>Employer pilot programme with measured repeat-hire and completion rates</li></ul>
    </div></div>
    <div class="roadmap__item"><div class="roadmap__phase"><span class="chip chip--later">○ Planned</span><strong style="color:var(--muted);font-size:.82rem">Phase 3</strong></div><div>
      <h3>Field-ready mobile</h3>
      <ul><li>Android and iOS builds with native Google sign-in</li><li>Push notifications for dispatch, attendance and settlement events</li><li>Offline-tolerant field flows for low-connectivity shifts</li><li>Local-language accessibility review (नेपाली)</li></ul>
    </div></div>
    <div class="roadmap__item"><div class="roadmap__phase"><span class="chip chip--later">○ Planned</span><strong style="color:var(--muted);font-size:.82rem">Phase 4</strong></div><div>
      <h3>Scale the trust layer</h3>
      <ul><li>Reputation scoring with transparent, contestable inputs</li><li>Dispute resolution SLAs and escalation tooling</li><li>Insurance or guarantee partnerships for high-value engagements</li><li>Employer tooling: bulk shifts, invoicing, workforce analytics</li><li>Multi-city operations and category expansion</li></ul>
    </div></div>
  </div>
  <div class="callout" style="max-width:820px;margin:38px 0 0"><strong>Sequencing logic</strong><p>Verification, a shared agreement and an auditable payment trail have to work together before volume is useful. We are deliberately not optimising for listing count until the trust loop closes end to end.</p></div>
</div></section>
</main>"""
page("roadmap.html", "Roadmap — Kalla-Lai", "The Kalla-Lai product roadmap with honest status labels: shipped, in progress and planned.", roadmap_body, "Roadmap")

# --------------------------------------------------------------------------
# 5. Trust & safety
# --------------------------------------------------------------------------
trust_body = f"""<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Trust & safety</div>
  <span class="eyebrow">Trust & safety</span>
  <h1>Trust is the product.</h1>
  <p>Not a badge, not a promise in a footer. Here are the actual controls built into the client, the API and the data model — and the ones still ahead of us.</p>
</div></section>

<section class="section"><div class="container">
  <div class="grid grid--2">
    {card('shield', 'Identity verification', 'A hosted KYC provider performs document OCR, selfie/face comparison and liveness checks. The user gives explicit consent, and approval arrives through an HMAC-signed webhook before the marketplace unlocks. A completed SDK session alone is never treated as proof.', '')}
    {card('lock', 'What we do not store', 'No document images, no face templates, no OCR payloads, no home street addresses. The platform keeps a session reference, consent version/time and decision state. Profile setup asks for an area or city, not a precise location.', 'green')}
    {card('code', 'API integrity', 'Role-based authorization on every marketplace route, idempotency keys for state changes, structured validation, rate limiting and signed webhook verification. Access tokens are short-lived with rotating refresh sessions.', '')}
    {card('wallet', 'Money, honestly modelled', 'An escrow-style ledger separates agreed, approved and settled amounts and includes review and dispute states. Real settlement requires a licensed payment provider; the UI is built never to claim funds moved without confirmation.', 'amber')}
    {card('users', 'Two-sided accountability', 'Worker reputation and employer credibility are both first-class. Rich profiles, work history and completion records give each side information before they agree to a shift.', '')}
    {card('star', 'Honest UI states', 'No "verified" badge without an approved decision. No "paid" label without a confirmed settlement. No "published" job without a persisted requisition. The interface is designed to fail visibly and safely.', 'green')}
  </div>
  <div class="callout callout--amber" style="max-width:860px;margin:38px 0 0"><strong>Still to complete before production</strong><p>Payment-provider settlement and payouts, per-market KYC and consent review, retention and deletion policies, legal and labour review, private object storage for profile media, and full release testing. These are tracked openly in the <a href="roadmap.html">roadmap</a> and the <a href="{REPO}/blob/master/startup/LEGAL-CHECKLIST.md">legal checklist</a>.</p></div>
  <p style="margin-top:30px"><a class="btn btn--primary" href="{REPO}/blob/master/security-privacy/README.md">Read the security & privacy documentation <span class="arrow">↗</span></a></p>
</div></section>
</main>"""
page("trust.html", "Trust & safety — Kalla-Lai", "How Kalla-Lai handles identity verification, data minimisation, API integrity, payment state and honest UI states.", trust_body, "Trust & safety")

# --------------------------------------------------------------------------
# 6. FAQ
# --------------------------------------------------------------------------
faq_body = """<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / FAQ</div>
  <span class="eyebrow">FAQ</span>
  <h1>Straight answers.</h1>
  <p>Including the uncomfortable ones about what isn't finished yet.</p>
</div></section>
<section class="section"><div class="container">
  <div style="max-width:820px;margin:0 auto">__FAQ__</div>
  <div class="callout" style="max-width:820px;margin:38px auto 0"><strong>Something missing?</strong><p>Open an issue or start a discussion in the <a href="__REPO__/issues">GitHub repository</a>, or <a href="contact.html">get in touch</a> directly.</p></div>
</div></section>
</main>""".replace("__FAQ__", faq_markup(faq_items)).replace("__REPO__", REPO)
page("faq.html", "FAQ — Kalla-Lai", "Frequently asked questions about Kalla-Lai: what it is, verification, payments, availability and partnerships.", faq_body)

# --------------------------------------------------------------------------
# 7. Pitch deck
# --------------------------------------------------------------------------
slides = [
    ("01 · Title", "Kalla-Lai", "Work, verified. A trusted two-sided marketplace for everyday local work — starting in Nepal. <br><br><span style='color:var(--indigo);font-weight:700'>Early-stage · Product built · Pilots next</span>"),
    ("02 · Problem", "Everyday work still runs on promises", "Found by word of mouth. Agreed in chat. Settled in cash. <br><br><ul><li>Workers have no portable proof of reliability</li><li>Employers cannot check who is arriving</li><li>Neither side has a shared record when something goes wrong</li></ul>"),
    ("03 · Insight", "The gap isn't discovery. It's trust.", "Job boards solved listing volume and stopped. They don't know whether the person showed up, the work was completed, or the payment was right. <br><br>The durable business is the layer both sides trust enough to <strong>settle through</strong>."),
    ("04 · Solution", "One shared journey, both sides", "<ul><li>Verified identity through a specialist KYC provider</li><li>Rich worker and employer profiles with reputation</li><li>Area-based discovery and structured requisitions</li><li>Shift, attendance, completion and review states</li><li>Escrow-style ledger with a dispute path</li></ul>"),
    ("05 · Why now", "The infrastructure finally got cheap", "<ul><li>A smartphone, camera and connectivity in every pocket</li><li>Hosted document + liveness verification as an API</li><li>Digital settlement is already normal behaviour</li></ul><br>The remaining work is product and operations — not fundamental infrastructure."),
    ("06 · Product", "Built, not mocked up", "<ul><li>Working Flutter web client — open it from this site</li><li>Live Node/TypeScript API with Supabase Postgres</li><li>Role-based access, migrations, signed verification webhook</li><li>Open architecture, workflow, security, privacy and QA docs</li></ul>"),
    ("07 · Trust", "Honesty is a feature", "The UI never claims a worker was verified, money moved, or a job was published unless an authoritative service confirms it. <br><br>No identity images or biometric templates stored — only a session reference, consent record and decision state."),
    ("08 · Model", "Transparent take on settled shifts", "Primary: a transparent service or transaction fee on completed, settled shifts. <br><br>Expansion: employer tooling — bulk shifts, invoicing, workforce analytics. <br><br><em>Pricing and unit economics are pilot questions, not deck assumptions.</em>"),
    ("09 · Moat", "Repetition compounds", "Every completed shift leaves a verified record: who did the work, what was agreed, that it was completed and settled. <br><br>The second hire is cheaper, the tenth nearly frictionless. The moat is the trust history, not the listing count."),
    ("10 · Stage & risks", "What's real, what's open", "<strong>Real:</strong> working product, live API, documented architecture, KYC integration path, ledger model. <br><br><strong>Open:</strong> licensed settlement, per-market KYC/consent review, supply density, legal review, mobile release."),
    ("11 · Ask", "Let's run a pilot", "Looking for employer partners with recurring shift demand, identity/payment/insurance infrastructure partners, and early-stage investors with marketplace operating experience. <br><br><a class='btn btn--primary' href='contact.html' style='margin-top:18px'>Get in touch →</a>"),
]
slide_html = "".join(
    f'<div class="slide" {"hidden" if i else ""}><div class="slide__num">{n}</div><h2>{t}</h2><div style="font-size:1.08rem;color:var(--body);max-width:820px">{b}</div></div>'
    for i, (n, t, b) in enumerate(slides)
)
pitch_body = f"""<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Pitch deck</div>
  <span class="eyebrow">Pitch deck</span>
  <h1>The whole story in eleven slides.</h1>
  <p>Use the arrow keys or the buttons below. No invented metrics, no hidden assumptions.</p>
</div></section>
<section class="deck"><div class="container">
  <div class="deck__frame">{slide_html}</div>
  <div class="deck__controls">
    <button type="button" data-deck-prev>← Previous</button>
    <span class="deck__count">1 / {len(slides)}</span>
    <button type="button" data-deck-next>Next →</button>
  </div>
  <p style="text-align:center;color:#aab3d4;font-size:.86rem;margin-top:22px">Also available as <a href="{REPO}/blob/master/startup/PITCH-DECK.md" style="color:#c9cff0">markdown in the startup kit</a>.</p>
</div></section>
</main>"""
page("pitch.html", "Pitch deck — Kalla-Lai", "An eleven-slide investor pitch for Kalla-Lai: problem, insight, solution, product, model, moat, stage and the ask.", pitch_body)

# --------------------------------------------------------------------------
# 8. Contact
# --------------------------------------------------------------------------
contact_script = """<script>
(function(){
  var form = document.getElementById('contact-form');
  if (!form) return;
  form.addEventListener('submit', function(e){
    e.preventDefault();
    var name = (form.elements['name'].value || '').trim();
    var kind = form.elements['kind'].value;
    var msg = (form.elements['message'].value || '').trim();
    if (!msg) { form.elements['message'].focus(); return; }
    var title = encodeURIComponent('[' + kind + '] ' + (name || 'Website enquiry'));
    var body = encodeURIComponent(msg + '\\n\\n— Sent from kalla-lai website' + (name ? ' (' + name + ')' : ''));
    window.open('__REPO__/issues/new?title=' + title + '&body=' + body, '_blank', 'noopener');
    document.getElementById('contact-sent').hidden = false;
  });
})();
</script>""".replace("__REPO__", REPO)
contact_body = f"""<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Contact</div>
  <span class="eyebrow">Contact</span>
  <h1>Let's build this properly.</h1>
  <p>Employer pilots, infrastructure partnerships, investor conversations, or a bug you found — we want to hear it.</p>
</div></section>
<section class="section"><div class="container">
  <div class="grid grid--2" style="gap:56px;align-items:start">
    <div class="card" style="padding:34px">
      <h3 style="font-size:1.4rem;margin-bottom:8px">Send a message</h3>
      <p style="margin-bottom:22px">This opens a pre-filled issue in our public repository, so your message is tracked and answerable. For private conversations, mention that in the message and we'll follow up.</p>
      <form id="contact-form">
        <div style="display:grid;gap:14px">
          <label style="font-size:.86rem;font-weight:700;color:var(--navy)">Your name (optional)
            <input name="name" type="text" autocomplete="name" placeholder="How should we address you?" style="display:block;width:100%;margin-top:6px;padding:13px 14px;border:1px solid var(--line-strong);border-radius:12px">
          </label>
          <label style="font-size:.86rem;font-weight:700;color:var(--navy)">What is it about?
            <select name="kind" style="display:block;width:100%;margin-top:6px;padding:13px 14px;border:1px solid var(--line-strong);border-radius:12px;background:#fff">
              <option>Employer pilot</option><option>Investor conversation</option><option>Identity / payment partnership</option><option>Product feedback</option><option>Bug report</option><option>Something else</option>
            </select>
          </label>
          <label style="font-size:.86rem;font-weight:700;color:var(--navy)">Message
            <textarea name="message" rows="5" required placeholder="Tell us what you're working on…" style="display:block;width:100%;margin-top:6px;padding:13px 14px;border:1px solid var(--line-strong);border-radius:12px;resize:vertical"></textarea>
          </label>
          <button class="btn btn--primary" type="submit">Open pre-filled message <span class="arrow">→</span></button>
        </div>
      </form>
      <p id="contact-sent" class="callout" style="margin:20px 0 0" hidden><strong>Ready to send.</strong><p>A new tab opened with your message pre-filled — submit it there and we'll get back to you.</p></p>
    </div>
    <div>
      <div class="card reveal" style="margin-bottom:18px"><h3>Employer pilots</h3><p>Have recurring shift-based hiring? Tell us the category, the city and the weekly volume. We'll show you exactly what the product handles today and where it doesn't.</p></div>
      <div class="card reveal" style="margin-bottom:18px"><h3>Investors</h3><p>Read the <a href="investors.html">investor brief</a> and the <a href="pitch.html">pitch deck</a> first. Bring the hard questions about payments, KYC and supply density — those are the interesting ones.</p></div>
      <div class="card reveal" style="margin-bottom:18px"><h3>Engineers & designers</h3><p>The whole codebase and documentation are public. Issues and pull requests are the fastest way in.</p><p style="margin-top:12px"><a class="btn btn--ghost btn--sm" href="{REPO}">Open the repository <span class="arrow">↗</span></a></p></div>
      <div class="callout callout--amber"><strong>Note for the founding team</strong><p>Replace this GitHub-issue flow with a real inbox (for example a verified <code>hello@</code> address) and a CRM once the domain and mail provider are configured. Tracked in the startup kit legal/ops checklist.</p></div>
    </div>
  </div>
</div></section>
</main>"""
page("contact.html", "Contact — Kalla-Lai", "Get in touch with Kalla-Lai about employer pilots, partnerships, investing, product feedback or bugs.", contact_body, extra_script=contact_script)

# --------------------------------------------------------------------------
# 9. Legal drafts
# --------------------------------------------------------------------------
legal_banner = """<div class="callout callout--amber"><strong>Draft for review — not legal advice</strong><p>This is a plain-language working draft prepared for an early-stage product. It has not been reviewed by a lawyer and is not yet a binding agreement. Have qualified counsel in your launch jurisdiction review it before the service accepts real users, payments or identity data.</p></div>"""

privacy_body = f"""<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Privacy</div>
  <span class="eyebrow">Privacy</span>
  <h1>Privacy notice</h1>
  <p>Last updated: <span data-year>2026</span> · Plain-language working draft</p>
</div></section>
<section class="section"><div class="container prose">
  {legal_banner}
  <h2>1. Who we are</h2>
  <p>Kalla-Lai (कल्ला-लाई) is an early-stage two-sided work marketplace. This notice explains what the current product does with information. As the service matures, this document will be replaced with a formally reviewed policy naming the legal entity, data controller and a dedicated contact address.</p>
  <h2>2. What the app collects</h2>
  <ul>
    <li><strong>Account data:</strong> email address, display name, role (worker or employer), and a hashed password credential or a Firebase identity token.</li>
    <li><strong>Profile data:</strong> skills, area or city, languages, bio, portfolio links, organisation details and optional profile media. We ask for an area, not a home street address.</li>
    <li><strong>Marketplace data:</strong> requisitions, applications, shift and attendance states, reviews, dispute records and ledger entries.</li>
    <li><strong>Technical data:</strong> access and refresh tokens, request metadata needed for security and reliability, and locally stored preferences (theme, language, notification setting, API endpoint override).</li>
  </ul>
  <h2>3. Identity verification</h2>
  <p>Document, selfie and liveness checks are performed by a specialist hosted provider. Kalla-Lai does <strong>not</strong> receive or store identity-document images, face templates or OCR payloads. We keep a session reference, the consent version and time, and the provider's decision state. Verification is only reflected in the app after an HMAC-signed provider webhook confirms approval. The provider's own privacy notice governs its processing.</p>
  <h2>4. What we do not do</h2>
  <ul><li>We do not sell personal data or use it for advertising.</li><li>We do not claim a worker is verified, a job is published or money has moved without an authoritative confirmation.</li><li>We do not request precise home addresses or continuous location tracking in the current product.</li></ul>
  <h2>5. Where data lives</h2>
  <p>The API uses a managed Postgres database (Supabase) and a hosted deployment. Locally stored preferences and session tokens are kept in your browser's storage so you stay signed in. Signing out clears the saved session on that device.</p>
  <h2>6. Retention and deletion</h2>
  <p>A formal retention schedule and a self-service deletion flow are open items on the <a href="roadmap.html">roadmap</a>. Until they are implemented, contact us through the <a href="contact.html">contact page</a> to request deletion of an account.</p>
  <h2>7. Your choices</h2>
  <ul><li>Edit profile details from the app at any time.</li><li>Sign out to clear the saved session on the current device.</li><li>Choose theme, language and notification preferences in Settings.</li><li>Request access to or deletion of your data via the contact page.</li></ul>
  <h2>8. Changes</h2>
  <p>This draft will change as the product and its legal review progress. Material changes will be highlighted in the repository and in the app.</p>
</div></section>
</main>"""
page("privacy.html", "Privacy notice — Kalla-Lai", "Plain-language draft privacy notice for the Kalla-Lai marketplace: what is collected, how verification works, and your choices.", privacy_body)

terms_body = f"""<main id="main">
<section class="page-hero"><div class="container">
  <div class="crumbs"><a href="index.html">Home</a> / Terms</div>
  <span class="eyebrow">Terms</span>
  <h1>Terms of service</h1>
  <p>Last updated: <span data-year>2026</span> · Plain-language working draft</p>
</div></section>
<section class="section"><div class="container prose">
  {legal_banner}
  <h2>1. About this build</h2>
  <p>Kalla-Lai is an early-stage, publicly accessible product preview. It is provided to demonstrate and validate the marketplace workflow. It is <strong>not</strong> yet a production-grade employment, staffing or payment service, and it does not currently settle real money. Please treat all data entered as non-production data.</p>
  <h2>2. Using the service</h2>
  <ul><li>Provide accurate information about yourself and the work you offer or request.</li><li>Use one account per person or organisation, and keep your credentials secure.</li><li>Do not use the service to impersonate someone, misrepresent verification status, post unlawful work, or harass other users.</li><li>Do not attempt to bypass access controls, probe the API for vulnerabilities without authorisation, or interfere with other users' data.</li></ul>
  <h2>3. Roles and relationships</h2>
  <p>Kalla-Lai provides a marketplace and record-keeping layer. It is not an employer of workers, nor an agent of employers, and it does not currently act as a payment institution. Agreements for work are between the worker and the employer. Nothing in the app constitutes legal, employment, tax or financial advice.</p>
  <h2>4. Verification</h2>
  <p>Identity checks are performed by a third-party provider. A verification badge reflects a provider decision confirmed through a signed webhook; it is not a guarantee of a person's conduct, skills or suitability. Employers remain responsible for their own hiring decisions.</p>
  <h2>5. Payments and disputes</h2>
  <p>The current build models an escrow-style ledger and dispute states but does not hold, transfer or settle funds. Any payment arrangement shown in the preview is illustrative. Licensed settlement is a roadmap item and will be governed by separate terms with the relevant provider when launched.</p>
  <h2>6. Availability and changes</h2>
  <p>The preview may change, reset or become unavailable without notice. Demo and preview data may be removed. We aim to be transparent about the state of the product — see the <a href="roadmap.html">roadmap</a>.</p>
  <h2>7. Intellectual property</h2>
  <p>The client, API and documentation are published in the <a href="{REPO}">public repository</a>. Refer to the repository for its licensing status before reusing any material. The Kalla-Lai name and logo remain the property of the project.</p>
  <h2>8. Liability</h2>
  <p>To the extent permitted by law, the preview is provided "as is" without warranties. Because this is an early-stage preview without production payments or regulated verification, users should not rely on it for decisions with financial or safety consequences.</p>
  <h2>9. Contact</h2>
  <p>Questions about these terms can be raised through the <a href="contact.html">contact page</a> or as an issue in the public repository.</p>
</div></section>
</main>"""
page("terms.html", "Terms of service — Kalla-Lai", "Plain-language draft terms for the early-stage Kalla-Lai product preview.", terms_body)

# --------------------------------------------------------------------------
# 10. 404
# --------------------------------------------------------------------------
not_found_body = """<main id="main">
<section class="section" style="text-align:center;min-height:60vh;display:grid;align-content:center">
  <div class="container">
    <div class="slide__big" style="font-size:clamp(4rem,14vw,9rem)">404</div>
    <h2 style="margin:10px 0 16px">This shift doesn't exist.</h2>
    <p class="lead" style="max-width:520px;margin:0 auto 28px">The page you were looking for has moved, or never made it onto the schedule. Let's get you back to work.</p>
    <div class="btn-row" style="justify-content:center"><a class="btn btn--primary" href="index.html">Back to home →</a><a class="btn btn--ghost" href="app/">Open the app</a></div>
  </div>
</section>
</main>"""
page("404.html", "Page not found — Kalla-Lai", "The page you requested could not be found. Return to the Kalla-Lai homepage or open the app.", not_found_body)

# --------------------------------------------------------------------------
# Assets that must exist at the site root
# --------------------------------------------------------------------------
(OUT / ".nojekyll").write_text("", encoding="utf-8")
print("wrote .nojekyll")

robots = """User-agent: *
Allow: /

Sitemap: https://innovator123-sudo.github.io/kalla-lai/sitemap.xml
"""
(OUT / "robots.txt").write_text(robots, encoding="utf-8")

pages_for_sitemap = ["", "about.html", "investors.html", "roadmap.html", "trust.html", "faq.html", "pitch.html", "contact.html", "privacy.html", "terms.html", "app/"]
sitemap = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
for p in pages_for_sitemap:
    sitemap.append(f"  <url><loc>https://innovator123-sudo.github.io/kalla-lai/{p}</loc></url>")
sitemap.append("</urlset>")
(OUT / "sitemap.xml").write_text("\n".join(sitemap) + "\n", encoding="utf-8")
print("wrote robots.txt, sitemap.xml")

print(f"\nDone: {len(list((OUT).glob('*.html')))} HTML pages in {OUT}")
