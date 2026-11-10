# Kalla-Lai — Brand Guide

The website, the app and the docs should look and sound like one company. This file is the source of truth.

---

## 1. Name

**Kalla-Lai** · **कल्ला-लाई**

- Always write the Latin name as `Kalla-Lai` with a hyphen and both capitals.
- The Devanagari form is part of the primary logo, not a translation to swap in and out.
- Never write `kalla_lai` in prose — that form is only for package identifiers, file names and the repository.
- Do not abbreviate to "KL" in public-facing copy.

**Tagline:** *Work, verified.*
**Supporting line:** *Found nearby. Paid with confidence.*

---

## 2. Logo

Source: `assets/images/kalla_lai_logo.png`. Web-ready variants are generated into `site/assets/img/`:

| File | Use |
| --- | --- |
| `kalla_lai_logo.png` | Transparent colour logo for white / light surfaces |
| `kalla_lai_logo_white.png` | White monochrome for navy / dark surfaces |
| `og-cover.svg` | Social share image (1200×630) |
| `favicon.png` | Browser icon |

The mark is a mountain outline over three figures (indigo, amber, indigo) above curved horizon lines, followed by the Devanagari wordmark.

**Rules**
- Keep clear space around the logo equal to the height of the mountain peak.
- Minimum display height: 32 px. Below that the Devanagari becomes unreadable.
- Never stretch, recolor, rotate, add a drop shadow, or place the colour logo on a dark background.
- Use the white variant on navy; never apply a CSS `filter: invert()` to the colour PNG (its background is transparent, but the coloured figures would be lost).
- Do not reconstruct the mark from emoji or approximate shapes.

---

## 3. Colour

| Token | Hex | Use |
| --- | --- | --- |
| Navy | `#101A3A` | Wordmark, headings, dark sections, footer |
| Ink | `#101828` | Body headings, darkest text |
| Indigo | `#5B4BD6` | Primary brand colour, CTAs, links, active states |
| Indigo dark | `#4338CA` | Hover / pressed |
| Violet | `#7C6BF2` | Gradients, focus rings, secondary accents |
| Amber | `#F5A623` | Highlight, secondary CTA, brand accent dot |
| Amber soft | `#FFF4DD` | Amber-tinted surfaces |
| Body | `#4A556B` | Paragraph text |
| Muted | `#6B768D` | Captions, meta |
| Tint | `#F7F8FD` | Alternating section background |
| Tint 2 | `#EEF0FB` | Tab rails, subtle fills |
| Line | `#E6E9F3` | Borders and dividers |
| White | `#FFFFFF` | Canvas |

The CSS variables live in `site/assets/css/styles.css` (`:root`). Change them there, not in individual pages.

**Contrast:** body text on white uses `#4A556B` (well above 4.5:1). White text on indigo `#5B4BD6` is used only for buttons at ≥16 px semi-bold. Never put body copy on the amber.

---

## 4. Typography

- **Primary:** Plus Jakarta Sans (Google Fonts), weights 400 / 500 / 600 / 700 / 800.
- **Devanagari:** Noto Sans Devanagari, weights 600 / 700.
- **Fallback stack:** system UI fonts, so the site remains readable offline.
- Headings: weight 800, tight letter-spacing (`-0.025em`), line-height ~1.15.
- Body: 16 px / 1.65 line-height, colour `#4A556B`.
- Eyebrows: 0.76 rem, uppercase, letter-spacing `0.14em`, weight 800, indigo.

Never use more than three type sizes in a single section.

---

## 5. Shape & motion

- Corner radii: 12 / 18 / 26 / 36 px (`--r-sm` → `--r-xl`). Buttons and chips are fully rounded.
- Shadows are soft and cool-toned, never black.
- Cards lift 5 px on hover; buttons lift 2 px.
- Section reveal: 22 px upward fade over 600 ms, triggered by IntersectionObserver. Respect `prefers-reduced-motion`; content is visible without JS.
- The phone mockup floats slowly (6 s). Disable on mobile and for reduced motion.

---

## 6. Voice

**We sound:** plain, confident, specific, honest about what is unfinished.

| Do | Don't |
| --- | --- |
| "Verified identities" | "Military-grade AI-powered trust" |
| "An escrow-style ledger" (when real settlement isn't live) | "Money is safe with us" |
| "Early-stage · product built · pilots next" | "Trusted by thousands" |
| "We do not store document images" | "Your data is 100% secure" |
| "Licensed settlement is on the roadmap" | "Get paid instantly" (until it's true) |

**Hard rule:** never claim a worker was verified, money moved, or a job was published unless an authoritative service confirmed it. This applies to marketing copy, not just the app.

Use short sentences. Prefer concrete nouns over adjectives. Avoid startup jargon ("revolutionise", "seamless", "ecosystem", "empower").

---

## 7. Content patterns

- **Eyebrow + headline + one supporting sentence** at the start of every section.
- **Three cards** for problems, **four** for features, **two** for comparisons.
- **Status labels with real meaning:** `● Built`, `◐ In progress`, `○ Planned`. Never quietly upgrade a planned item to "built" in marketing copy.
- **Legal pages** carry a visible draft banner until counsel signs off.
- **No fake stats, no invented testimonials, no logo walls of partners we don't have.** If a number isn't measured, it isn't published.

---

## 8. Accessibility

- Semantic headings, one `h1` per page, skip link, labelled form controls.
- Visible focus ring (`--violet`, 3 px).
- All icons are decorative (`aria-hidden`); meaningful icons have text.
- Minimum 16 px body text, 4.5:1 contrast.
- Layout is responsive at 980 / 760 / 460 px; no horizontal scroll on a 390 px viewport.
- `prefers-reduced-motion` disables animation.

---

## 9. Applying the brand to a new page

1. Add the page to `tools/build_site.py` with `page(filename, title, description, body, active=...)`.
2. Use the shared `nav()` / `footer()` automatically injected by `page()`.
3. Reuse `section_head()`, `card()`, `icon()` and `phone_markup()` helpers.
4. Run `python tools/build_site.py`.
5. Add the URL to `sitemap.xml` generation in the same script.
6. Verify locally with a browser at both desktop and 390 px widths.
