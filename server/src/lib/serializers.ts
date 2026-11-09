import { coarsen, roundKm } from './geo.js';

/* eslint-disable @typescript-eslint/no-explicit-any */
type Row = Record<string, any>;

export function jobDto(row: Row, options: { exactLocation?: boolean; distanceKm?: number | null } = {}) {
  const exact = options.exactLocation === true;
  return {
    id: row.id,
    employerId: row.employer_id,
    role: row.role,
    description: row.description,
    workMode: row.work_mode,
    area: row.area,
    address: exact ? row.address : undefined,
    latitude:
      row.latitude === null || row.latitude === undefined
        ? undefined
        : exact
          ? Number(row.latitude)
          : coarsen(Number(row.latitude)),
    longitude:
      row.longitude === null || row.longitude === undefined
        ? undefined
        : exact
          ? Number(row.longitude)
          : coarsen(Number(row.longitude)),
    dispatchRadiusKm: Number(row.dispatch_radius_km),
    compensationType: row.compensation_type,
    rateNpr: Number(row.rate_npr),
    currency: row.currency,
    negotiable: row.negotiable,
    requiredSkills: row.required_skills ?? [],
    qualifications: row.qualifications ?? [],
    category: row.category ?? undefined,
    contactPhone: row.contact_phone ?? undefined,
    workingHours: row.working_hours ?? undefined,
    employmentType: row.employment_type ?? 'FULL_TIME',
    openings: row.openings === null || row.openings === undefined ? 1 : Number(row.openings),
    salaryIncrement: row.salary_increment === true,
    incrementNote: row.increment_note ?? undefined,
    status: row.status,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    distanceKm:
      options.distanceKm === undefined || options.distanceKm === null
        ? undefined
        : roundKm(Number(options.distanceKm)),
    employer: row.employer_display_name
      ? {
          displayName: row.employer_display_name,
          verified: row.employer_trust_status === 'VERIFIED',
        }
      : undefined,
  };
}

export function offerDto(row: Row) {
  return {
    id: row.id,
    jobId: row.job_id,
    employerId: row.employer_id,
    workerId: row.worker_id,
    rateNpr: Number(row.rate_npr),
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    status: row.status,
    message: row.message,
    respondedAt: row.responded_at,
    createdAt: row.created_at,
    job: row.role
      ? {
          role: row.role,
          area: row.area,
          requiredSkills: row.required_skills ?? [],
        }
      : undefined,
    employer: row.employer_display_name
      ? { displayName: row.employer_display_name, verified: row.employer_trust_status === 'VERIFIED' }
      : undefined,
  };
}

export function shiftDto(row: Row) {
  return {
    id: row.id,
    jobId: row.job_id,
    workerId: row.worker_id,
    employerId: row.employer_id,
    offerId: row.offer_id,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    status: row.status,
    onMyWayAt: row.on_my_way_at,
    startedAt: row.started_at,
    completionSubmittedAt: row.completion_submitted_at,
    completionNote: row.completion_note,
    approvedAt: row.approved_at,
    createdAt: row.created_at,
    job: row.role
      ? {
          role: row.role,
          area: row.area,
          address: row.address,
          latitude: row.latitude === null ? undefined : Number(row.latitude),
          longitude: row.longitude === null ? undefined : Number(row.longitude),
          requiredSkills: row.required_skills ?? [],
        }
      : undefined,
    counterpart: row.counterpart_name
      ? { name: row.counterpart_name, verified: row.counterpart_verified === 'VERIFIED' }
      : undefined,
    invoice: row.invoice_id
      ? {
          id: row.invoice_id,
          status: row.invoice_status,
          amountNpr: Number(row.invoice_amount_npr),
          currency: row.invoice_currency,
        }
      : undefined,
  };
}

export function invoiceDto(row: Row) {
  return {
    id: row.id,
    shiftId: row.shift_id,
    employerId: row.employer_id,
    workerId: row.worker_id,
    hours: Number(row.hours),
    rateNpr: Number(row.rate_npr),
    amountNpr: Number(row.amount_npr),
    currency: row.currency,
    status: row.status,
    issuedAt: row.issued_at,
    reviewDueAt: row.review_due_at,
    reminderSentAt: row.reminder_sent_at,
    escalatedAt: row.escalated_at,
    paidAt: row.paid_at,
  };
}
