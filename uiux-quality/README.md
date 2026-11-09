# UI/UX, Quality & Release README

## 1. Product design objective

The app should feel like a deliberately designed, trustworthy marketplace—not a generic template or a collection of AI-generated dashboard cards. Visual polish must come from coherent information architecture, purposeful details, consistent components, realistic content, and tested interactions.

## 2. Visual system

The product specification defines:

- Primary Slate Blue: `#0F172A`.
- Accent Indigo: `#4F46E5`.
- Success Green: `#16A34A`.
- Warning Amber: `#D97706`.
- Error Crimson: `#DC2626`.
- Inter typography; Roboto Mono for numeric pricing, status codes, and timestamps.

Turn these into explicit design tokens for color, typography, spacing, radii, elevation, borders, icons, motion, and component states. Semantic status must not rely on color alone; include text and/or an icon.

### Anti-template / anti-vibe-coded quality rules

- Build product-specific layouts around maps, work opportunities, portfolios, shift timelines, and payment review.
- Avoid repetitive generic cards when a table, map/list, timeline, form wizard, or focused detail view communicates better.
- Use one icon family; avoid random emoji/icon mixing and decorative gradients without purpose.
- Use realistic, localized sample content and NPR display formats where appropriate. Never publish fake testimonials, fabricated ratings, or placeholder copy.
- Ensure each visible button and link has a real action, disabled state where relevant, and feedback after completion.
- Design empty, loading, offline, error, success, permission-denied, and verification-pending states.
- Use purposeful motion with reduced-motion support.
- Validate the design with real workers and employers; do not treat a screenshot review as a usability test.

## 3. Main navigation and screen requirements

The source defines two modes at launch:

### Vacancy mode — worker

- Nearby work map with clustered pins, distance badges, commute estimates, and pay rates.
- Bottom draggable job preview sheet and a clear mode switch.
- Job detail and negotiation view with role, employer trust indicator, location/geofence information, pay, requirements, and apply/accept action.
- Worker profile and portfolio: verification badge, video pitch, CV preview, skills, rates, and negotiability.
- Active shift timeline with **On My Way**, site instructions, contact details, and arrival/completion actions.
- Payment status and dispute/flag flow.

### Hiring mode — employer

- Job requisition wizard: role, location, work mode, budget, skills, education/certification, and review before publishing.
- Candidate/application view with only job-relevant, authorized information.
- Shift monitoring with authorized worker status and ETA.
- Completion review, invoice, payment state, and dispute handling.

### Shared screens

- Sign-in and account recovery.
- Verification progress and help/appeal.
- Conversations and notifications.
- Language, accessibility, privacy, security, and account settings.

## 4. High-trust interaction details

Before a worker accepts a shift, clearly show:

- Role and actual work description.
- Location precision and travel expectations.
- Shift start/end time and expected duration.
- Total pay, fees/deductions, and payment review conditions.
- Required skills and qualifications.
- Employer trust/verification information available for display.
- Cancellation rules and a safety/contact path.

Before an employer confirms a worker, show relevant verified status and work-related experience, not raw identity documents or unnecessary sensitive information.

Location permission should be requested only when the user starts a location-dependent action. Explain why it is required and support manual location entry where possible.

## 5. Accessibility and localization

The original spec calls for WCAG 2.1 AA, 48x48 dp touch targets, dynamic font scaling, and screen-reader tags. The addendum raises web surfaces to a WCAG 2.2 AA target where applicable. Confirm which standard applies to each platform and test it; do not claim conformance without an audit.

Requirements:

- Visible focus and keyboard navigation for web/admin surfaces.
- Screen-reader labels and logical reading order.
- Dynamic text sizing without clipped content.
- Sufficient text and control contrast.
- Touch targets around 44–48 dp where platform guidance applies.
- Reduced-motion preference support.
- Clear language selection and consistent translations; avoid accidental mixed-language UI.
- Localized dates, numbers, addresses, and NPR currency display where appropriate.

## 6. Screen-state checklist

Every key screen should define the following states as applicable:

| State | Expected behavior |
|---|---|
| Initial/loading | Clear progress feedback; prevent duplicate submissions |
| Empty | Explain why no content appears and provide a useful next action |
| Success | Confirm the action and show the resulting state |
| Validation error | Identify the field/problem and explain how to fix it |
| Network/server error | Preserve safe user input and provide retry/help |
| Offline | Explain what is unavailable; never fake a successful server action |
| Permission denied | Explain impact and offer a settings/manual alternative |
| Restricted/pending | Explain status and next step without exposing sensitive internal details |

## 7. Design and implementation workflow

1. Map the task journey and its business states before designing screens.
2. Create low-fidelity flows for both worker and employer modes.
3. Establish design tokens and reusable components.
4. Prototype realistic map, job, profile, shift, invoice, and dispute screens.
5. Test the core journeys with representative users.
6. Implement using Flutter widgets and feature-level Bloc/Cubit state.
7. Compare implementation with approved designs on supported phone sizes and text scales.
8. Fix visual, interaction, and accessibility defects before release.

## 8. Quality and testing plan

- Unit tests for domain use cases, state transitions, validators, and calculations.
- Widget tests for form validation, screen states, and critical controls.
- Integration tests for onboarding, posting a job, applying/accepting, shift reminders, completion, invoice review, and dispute creation.
- API tests for authorization, validation, idempotency, and error handling.
- Map/location tests for denied permissions, coarse location, inaccurate GPS, offline behavior, and shift completion cleanup.
- Accessibility checks with assistive technology and dynamic text sizes.
- Usability tests for first-time workers and employers.
- Load tests for the specified geospatial target: under 250 ms for a 25 km radius at 10,000 concurrent active users.
- Reliability tests against the 99.95% API availability target after deployment architecture and monitoring are defined.

## 9. Release gates

A release is not ready until:

- Core worker and employer flows pass end-to-end tests.
- Every visible control has a working outcome and meaningful feedback.
- Design components and typography/status patterns are consistent.
- Accessibility and responsive checks pass on supported devices.
- Private routes enforce server-side authorization and negative access tests pass.
- No secrets or sensitive personal data leak into client bundles or routine logs.
- High-risk security testing is complete; critical/high findings are closed or formally risk-accepted with mitigations.
- Production secrets, monitoring, backups, restore tests, and incident contacts are in place.
- Privacy notice, consent, retention policy, and local legal review are complete.
- Payment, escrow/holding, fee, refund, and dispute rules are approved and tested.

## 10. Non-functional targets and caveats

The specification gives a 250 ms geospatial-query target under a stated radius/load and 99.95% API uptime. These are target benchmarks, not current guarantees. Define measurement windows, percentiles, exclusions, monitoring dashboards, and operational ownership before using them as SLAs.
