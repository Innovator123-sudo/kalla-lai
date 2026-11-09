import bcrypt from 'bcryptjs';
import { closeDb, initDb, withTransaction } from './index.js';
import { migrate } from './migrate.js';

/**
 * Synthetic demo data only. Never run this against an environment that holds
 * real user, identity or payment records.
 */

const DEMO_PASSWORD = 'DemoPass123!';
// Separate, deliberately weak credential for the demo platform admin only.
const ADMIN_PASSWORD = 'admin';

const users = [
  {
    id: '11111111-1111-4111-8111-111111111111',
    email: 'worker@kallalai.demo',
    name: 'Anisha Gurung',
    role: 'WORKER',
    phone: '+9779800000001',
    identityStatus: 'VERIFIED',
    onboardingComplete: true,
  },
  {
    id: '22222222-2222-4222-8222-222222222222',
    email: 'worker2@kallalai.demo',
    name: 'Bikash Shrestha',
    role: 'WORKER',
    phone: '+9779800000002',
    identityStatus: 'PENDING',
    onboardingComplete: true,
  },
  {
    id: '33333333-3333-4333-8333-333333333333',
    email: 'employer@kallalai.demo',
    name: 'Sita Maharjan',
    role: 'EMPLOYER',
    phone: '+9779800000003',
    identityStatus: 'VERIFIED',
    onboardingComplete: true,
  },
  {
    id: '44444444-4444-4444-8444-444444444444',
    email: 'moderator@kallalai.demo',
    name: 'Platform Moderator',
    role: 'MODERATOR',
    phone: null,
    identityStatus: 'NOT_STARTED',
    onboardingComplete: true,
  },
  {
    id: '55555555-5555-4555-8555-555555555555',
    email: 'billing@kallalai.demo',
    name: 'Billing Administrator',
    role: 'BILLING_ADMIN',
    phone: null,
    identityStatus: 'NOT_STARTED',
    onboardingComplete: true,
  },
  {
    id: '66666666-6666-4666-8666-666666666660',
    email: 'admin@kallalai.demo',
    name: 'Platform Admin',
    role: 'ADMIN',
    phone: null,
    identityStatus: 'VERIFIED',
    onboardingComplete: true,
  },
] as const;

const skills: Array<[string, string]> = [
  ['electrical-safety', 'Electrical safety'],
  ['trade-certificate', 'Trade certificate'],
  ['pipe-repair', 'Pipe repair'],
  ['own-hand-tools', 'Own hand tools'],
  ['hvac-maintenance', 'HVAC maintenance'],
  ['safety-induction', 'Safety induction'],
  ['warehouse-operations', 'Warehouse operations'],
  ['inventory-counting', 'Inventory counting'],
  ['teaching', 'Teaching'],
  ['ui-design', 'UI design'],
  ['figma', 'Figma'],
];

const jobs = [
  {
    id: '66666666-6666-4666-8666-666666666661',
    role: 'Certified Electrician',
    description:
      'Inspect distribution panels and complete a scheduled safety check for a small commercial site.',
    area: 'Koteshwor, Kathmandu',
    address: 'Koteshwor-32, Kathmandu',
    lat: 27.6766,
    lng: 85.3473,
    rate: 1800,
    skills: ['electrical-safety', 'trade-certificate'],
    status: 'PUBLISHED',
  },
  {
    id: '66666666-6666-4666-8666-666666666662',
    role: 'Commercial Plumber',
    description: 'Repair a leaking supply line and test fixtures in a commercial kitchen.',
    area: 'Balkumari, Lalitpur',
    address: 'Balkumari-05, Lalitpur',
    lat: 27.6728,
    lng: 85.3242,
    rate: 2200,
    skills: ['pipe-repair', 'own-hand-tools'],
    status: 'FILLED',
  },
  {
    id: '66666666-6666-4666-8666-666666666663',
    role: 'HVAC Technician',
    description: 'Assist with preventive maintenance and document equipment checks.',
    area: 'Lazimpat, Kathmandu',
    address: 'Lazimpat-02, Kathmandu',
    lat: 27.7102,
    lng: 85.3222,
    rate: 2500,
    skills: ['hvac-maintenance', 'safety-induction'],
    status: 'PUBLISHED',
  },
  {
    id: '66666666-6666-4666-8666-666666666664',
    role: 'Warehouse Associate',
    description: 'Support a weekend inventory count and organise inbound stock.',
    area: 'Balaju, Kathmandu',
    address: 'Balaju Industrial Area, Kathmandu',
    lat: 27.7351,
    lng: 85.3013,
    rate: 1500,
    skills: ['warehouse-operations', 'inventory-counting'],
    status: 'PUBLISHED',
  },
  {
    id: '66666666-6666-4666-8666-666666666665',
    role: 'Secondary Maths Teacher',
    description: 'Cover two Grade 9 mathematics classes for a staff absence.',
    area: 'Patan, Lalitpur',
    address: 'Patan Dhoka, Lalitpur',
    lat: 27.6733,
    lng: 85.3163,
    rate: 3000,
    skills: ['teaching'],
    status: 'PUBLISHED',
  },
  {
    id: '66666666-6666-4666-8666-666666666666',
    role: 'Product UI Designer',
    description: 'Short remote engagement to refine a booking flow and produce a Figma handoff.',
    area: 'Remote',
    address: undefined,
    lat: 27.7172,
    lng: 85.324,
    rate: 4000,
    skills: ['ui-design', 'figma'],
    status: 'PUBLISHED',
    workMode: 'REMOTE',
  },
] as const;

async function seed() {
  await initDb();
  await migrate();
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 12);
  const adminPasswordHash = await bcrypt.hash(ADMIN_PASSWORD, 12);

  await withTransaction(async (tx) => {
    for (const user of users) {
      const hash = user.role === 'ADMIN' ? adminPasswordHash : passwordHash;
      await tx.query(
        `INSERT INTO users (id, email, password_hash, full_name, phone, identity_status, onboarding_complete)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (id) DO UPDATE SET
           password_hash = EXCLUDED.password_hash,
           identity_status = EXCLUDED.identity_status,
           onboarding_complete = EXCLUDED.onboarding_complete`,
        [
          user.id,
          user.email,
          hash,
          user.name,
          user.phone ?? null,
          user.identityStatus,
          user.onboardingComplete,
        ],
      );
      await tx.query(
        `INSERT INTO user_roles (user_id, role) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
        [user.id, user.role],
      );
    }

    await tx.query(
      `INSERT INTO worker_profiles
         (user_id, public_name, base_area, latitude, longitude, min_rate_npr, rate_negotiable,
          availability, bio, verification_status)
       VALUES
         ($1, 'Anisha G.', 'Baneshwor, Kathmandu', 27.6895, 85.3436, 1600, true,
          'Weekdays and Saturday mornings', 'Licensed electrician with six years of commercial maintenance experience.', 'VERIFIED'),
         ($2, 'Bikash S.', 'Lalitpur', 27.6664, 85.3168, 1400, false,
          'Evenings and weekends', 'Warehouse and logistics support worker.', 'PENDING')
       ON CONFLICT (user_id) DO NOTHING`,
      ['11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222'],
    );

    await tx.query(
      `INSERT INTO employer_profiles (user_id, display_name, organization, trust_status)
       VALUES ($1, 'Sita M.', 'Maharjan Trading', 'VERIFIED')
       ON CONFLICT (user_id) DO NOTHING`,
      ['33333333-3333-4333-8333-333333333333'],
    );

    for (const [slug, name] of skills) {
      await tx.query(
        `INSERT INTO skills (slug, name) VALUES ($1, $2) ON CONFLICT (slug) DO NOTHING`,
        [slug, name],
      );
    }

    for (const [slug, years] of [
      ['electrical-safety', 6],
      ['trade-certificate', 6],
      ['hvac-maintenance', 2],
      ['warehouse-operations', 3],
    ] as const) {
      await tx.query(
        `INSERT INTO worker_skills (user_id, skill_id, years_experience)
         SELECT $1, id, $2 FROM skills WHERE slug = $3
         ON CONFLICT DO NOTHING`,
        ['11111111-1111-4111-8111-111111111111', years, slug],
      );
    }

    for (const job of jobs) {
      await tx.query(
        `INSERT INTO jobs
           (id, employer_id, role, description, work_mode, address, area, latitude, longitude,
            dispatch_radius_km, compensation_type, rate_npr, currency, negotiable,
            required_skills, qualifications, status, published_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'NPR',true,$13,'{}',$14,
                 CASE WHEN $14 = 'PUBLISHED' THEN now() - interval '2 hours' ELSE now() - interval '3 days' END)
         ON CONFLICT (id) DO NOTHING`,
        [
          job.id,
          '33333333-3333-4333-8333-333333333333',
          job.role,
          job.description,
          'workMode' in job ? job.workMode : 'ON_SITE',
          job.address ?? null,
          job.area,
          job.lat,
          job.lng,
          10,
          'HOURLY',
          job.rate,
          job.skills,
          job.status,
        ],
      );
    }

    await tx.query(
      `INSERT INTO applications (id, job_id, worker_id, status, message, created_at)
       VALUES
         ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '66666666-6666-4666-8666-666666666661',
          '22222222-2222-4222-8222-222222222222', 'APPLIED', 'Available this week.', now() - interval '1 day'),
         ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', '66666666-6666-4666-8666-666666666663',
          '11111111-1111-4111-8111-111111111111', 'SHORTLISTED', 'I have HVAC maintenance experience.', now() - interval '2 days')
       ON CONFLICT (job_id, worker_id) DO NOTHING`,
    );

    const offerId = '77777777-7777-4777-8777-777777777771';
    await tx.query(
      `INSERT INTO offers (id, job_id, employer_id, worker_id, rate_npr, starts_at, ends_at, status, message, responded_at)
       VALUES ($1, '66666666-6666-4666-8666-666666666662', '33333333-3333-4333-8333-333333333333',
               '11111111-1111-4111-8111-111111111111', 2200, now() + interval '2 hours',
               now() + interval '8 hours', 'ACCEPTED', 'Please bring your own hand tools.', now() - interval '1 hour')
       ON CONFLICT (id) DO NOTHING`,
      [offerId],
    );

    const activeShift = '88888888-8888-4888-8888-888888888881';
    await tx.query(
      `INSERT INTO shifts (id, job_id, worker_id, employer_id, offer_id, starts_at, ends_at, status, created_at)
       VALUES ($1, '66666666-6666-4666-8666-666666666662', '11111111-1111-4111-8111-111111111111',
               '33333333-3333-4333-8333-333333333333', $2, now() + interval '2 hours',
               now() + interval '8 hours', 'ACCEPTED', now() - interval '1 hour')
       ON CONFLICT (id) DO NOTHING`,
      [activeShift, offerId],
    );

    const overdueShift = '88888888-8888-4888-8888-888888888882';
    await tx.query(
      `INSERT INTO shifts (id, job_id, worker_id, employer_id, starts_at, ends_at, status,
                           on_my_way_at, started_at, completion_submitted_at, completion_note, approved_at)
       VALUES ($1, '66666666-6666-4666-8666-666666666664', '11111111-1111-4111-8111-111111111111',
               '33333333-3333-4333-8333-333333333333', now() - interval '3 days',
               now() - interval '3 days' + interval '6 hours', 'COMPLETED',
               now() - interval '3 days' - interval '1 hour', now() - interval '3 days',
               now() - interval '3 days' + interval '6 hours', 'Count completed and signed off by supervisor.',
               now() - interval '3 days' + interval '7 hours')
       ON CONFLICT (id) DO NOTHING`,
      [overdueShift],
    );
    await tx.query(
      `INSERT INTO invoices (id, shift_id, employer_id, worker_id, hours, rate_npr, amount_npr, currency,
                             status, issued_at, review_due_at)
       VALUES ('99999999-9999-4999-8999-999999999991', $1, '33333333-3333-4333-8333-333333333333',
               '11111111-1111-4111-8111-111111111111', 6, 1500, 1500, 'NPR',
               'AWAITING_EMPLOYER_REVIEW', now() - interval '3 days', now() - interval '1 day')
       ON CONFLICT (shift_id) DO NOTHING`,
      [overdueShift],
    );

    const paidShift = '88888888-8888-4888-8888-888888888883';
    await tx.query(
      `INSERT INTO shifts (id, job_id, worker_id, employer_id, starts_at, ends_at, status, approved_at)
       VALUES ($1, '66666666-6666-4666-8666-666666666665', '11111111-1111-4111-8111-111111111111',
               '33333333-3333-4333-8333-333333333333', now() - interval '10 days',
               now() - interval '10 days' + interval '4 hours', 'COMPLETED',
               now() - interval '10 days' + interval '5 hours')
       ON CONFLICT (id) DO NOTHING`,
      [paidShift],
    );
    const paidInvoice = '99999999-9999-4999-8999-999999999992';
    await tx.query(
      `INSERT INTO invoices (id, shift_id, employer_id, worker_id, hours, rate_npr, amount_npr, currency,
                             status, issued_at, review_due_at, paid_at)
       VALUES ($1, $2, '33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111',
               4, 3000, 3000, 'NPR', 'PAID', now() - interval '10 days',
               now() - interval '8 days', now() - interval '9 days')
       ON CONFLICT (shift_id) DO NOTHING`,
      [paidInvoice, paidShift],
    );
    await tx.query(
      `INSERT INTO payment_transactions (id, invoice_id, provider, provider_ref, provider_event_id,
                                         amount_npr, currency, status, idempotency_key)
       VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', $1, 'DEMO', 'demo-settlement-1',
               'demo-event-1', 3000, 'NPR', 'SETTLED', 'seed-payment-1')
       ON CONFLICT (id) DO NOTHING`,
      [paidInvoice],
    );
    await tx.query(
      `INSERT INTO ledger_entries (id, invoice_id, entry_type, amount_npr, currency, description)
       VALUES
         ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', $1, 'HOLD', 3000, 'NPR', 'Seed hold'),
         ('cccccccc-cccc-4ccc-8ccc-cccccccccccd', $1, 'RELEASE', 3000, 'NPR', 'Seed settlement')
       ON CONFLICT (id) DO NOTHING`,
      [paidInvoice],
    );

    await tx.query(
      `INSERT INTO reviews (id, shift_id, author_id, recipient_id, rating, text, revealed_at)
       VALUES
         ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1', $1, '33333333-3333-4333-8333-333333333333',
          '11111111-1111-4111-8111-111111111111', 5, 'Punctual and well prepared.', now() - interval '8 days'),
         ('dddddddd-dddd-4ddd-8ddd-ddddddddddd2', $1, '11111111-1111-4111-8111-111111111111',
          '33333333-3333-4333-8333-333333333333', 4, 'Clear instructions and on-time payment.', now() - interval '8 days')
       ON CONFLICT (shift_id, author_id) DO NOTHING`,
      [paidShift],
    );

    await tx.query(
      `INSERT INTO notifications (id, user_id, type, title, body, resource_type, resource_id, created_at)
       VALUES
         ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1', '11111111-1111-4111-8111-111111111111',
          'shift.upcoming', 'Shift starts soon', 'Your plumbing shift starts in 2 hours. Tap On My Way when you leave.',
          'shift', $1, now() - interval '20 minutes'),
         ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2', '11111111-1111-4111-8111-111111111111',
          'invoice.issued', 'Invoice issued', 'Your invoice for the warehouse shift is awaiting employer review.',
          'invoice', '99999999-9999-4999-8999-999999999991', now() - interval '3 days')
       ON CONFLICT (id) DO NOTHING`,
      [activeShift],
    );

    await tx.query(
      `INSERT INTO audit_events (id, actor_id, action, resource_type, resource_id, outcome)
       VALUES ('ffffffff-ffff-4fff-8fff-ffffffffffff', '33333333-3333-4333-8333-333333333333',
               'seed.demo_data', 'environment', 'demo', 'SUCCESS')
       ON CONFLICT (id) DO NOTHING`,
    );
  });

  // eslint-disable-next-line no-console
  console.log(`[seed] demo data ready. Password for every demo account: ${DEMO_PASSWORD}`);
  // eslint-disable-next-line no-console
  console.log('[seed] worker@kallalai.demo, employer@kallalai.demo, moderator@kallalai.demo, billing@kallalai.demo');
  // eslint-disable-next-line no-console
  console.log(`[seed] platform admin: admin@kallalai.demo (or "admin") / ${ADMIN_PASSWORD}`);
}

const isEntrypoint = process.argv[1] && /seed\.(ts|js)$/.test(process.argv[1]);
if (isEntrypoint) {
  seed()
    .then(() => closeDb())
    .catch(async (error) => {
      // eslint-disable-next-line no-console
      console.error('[seed] failed:', error);
      await closeDb().catch(() => undefined);
      process.exit(1);
    });
}

export { seed, DEMO_PASSWORD };
