# API & Real-Time Communication README

## 1. Scope

The source specification calls for an API gateway using REST and/or GraphQL, with WebSockets (Socket.IO/gRPC are named options) for bidirectional chat, continuous position streaming, and live shift-state synchronization. It does not provide concrete endpoint paths or request/response schemas. The examples below are proposed contracts for engineering discussion, not existing deployed APIs.

## 2. API design principles

- Use versioned, documented API contracts.
- Authenticate private requests and enforce object-level authorization on every request.
- Validate request bodies, query parameters, identifiers, and uploaded-file metadata.
- Use consistent error envelopes and do not leak stack traces or private existence information.
- Use pagination and bounded filters for list/search endpoints.
- Use idempotency keys for non-repeatable actions such as accepting an offer, submitting completion, and creating payment transactions.
- Use optimistic concurrency or explicit state-transition checks to prevent conflicting updates.
- Return only fields the caller is authorized to see.

## 3. Suggested API domains

| Domain | Example resource patterns (proposed) |
|---|---|
| Authentication | `/v1/auth/session`, `/v1/auth/refresh`, `/v1/auth/logout`, `/v1/auth/recovery` |
| Worker profiles | `/v1/workers/me`, `/v1/workers/me/skills`, `/v1/workers/me/media` |
| Verification | `/v1/verification/cases`, `/v1/verification/cases/{id}` |
| Jobs | `/v1/jobs`, `/v1/jobs/{jobId}`, `/v1/jobs/{jobId}/publish`, `/v1/jobs/{jobId}/cancel` |
| Discovery | `/v1/discovery/jobs`, `/v1/discovery/workers` (employer-only, scoped) |
| Applications/offers | `/v1/jobs/{jobId}/applications`, `/v1/offers/{offerId}/accept` |
| Shifts | `/v1/shifts/{shiftId}`, `/v1/shifts/{shiftId}/on-my-way`, `/v1/shifts/{shiftId}/completion` |
| Payments | `/v1/shifts/{shiftId}/invoice`, `/v1/payments/{paymentId}`, `/v1/disputes` |
| Reviews | `/v1/reviews`, `/v1/reviews/me` |
| Privacy/settings | `/v1/me/privacy`, `/v1/me/data-export`, `/v1/me/deletion-request` |

The exact route naming and whether REST or GraphQL is primary remain implementation decisions.

## 4. Example job creation contract (illustrative)

```json
{
  "role": "Mechanic",
  "description": "Vehicle maintenance support",
  "workMode": "ON_SITE",
  "location": {
    "address": "Employer-provided work address",
    "dispatchRadiusKm": 10
  },
  "compensation": {
    "type": "HOURLY",
    "amount": 1200,
    "currency": "NPR",
    "negotiable": false
  },
  "requiredSkills": ["vehicle-diagnostics", "maintenance"],
  "qualifications": []
}
```

The sample values are illustrative only. Validate amount ranges, currency, work mode, address precision, and applicable job policy on the server.

## 5. State-changing command patterns

Prefer explicit commands over unrestricted status patching. For example:

- `POST /offers/{id}/accept` rather than allowing the client to set `status = ACCEPTED`.
- `POST /shifts/{id}/on-my-way` rather than accepting arbitrary shift status from the client.
- `POST /shifts/{id}/completion` with completion evidence metadata.
- `POST /payments/{id}/confirm-review` or `POST /disputes` rather than allowing clients to set a payment to `PAID`.

The server must verify that the requested transition is valid for the actor, current state, schedule, and associated records.

## 6. Real-time channels

Recommended event groups:

| Event | Recipient | Purpose |
|---|---|---|
| `job.published` | Eligible workers | Refresh nearby vacancy results |
| `application.updated` | Applicant and authorized employer | Application state changes |
| `offer.created` | Target worker | New dispatch/offer alert |
| `offer.accepted` | Employer and worker | Confirm acceptance |
| `shift.status.updated` | Authorized shift participants | Synchronize shift state |
| `shift.location.updated` | Authorized employer/worker workflow | Location/ETA while active shift rules permit |
| `message.created` | Conversation participants | New chat message |
| `invoice.issued` | Employer and worker | Payment review begins |
| `payment.status.updated` | Authorized parties | Payment progress |
| `dispute.status.updated` | Parties and authorized support | Dispute resolution progress |

Events should include an event id, timestamp, schema version, resource id, and minimal payload. Clients should fetch the authorized resource after an event rather than trusting event payloads as a complete source of truth.

## 7. WebSocket authorization and reliability

- Authenticate the socket connection and authorize each room/channel subscription.
- Re-check access when a user joins a job, shift, or conversation channel.
- Do not expose all worker coordinates to all nearby employers.
- Use sequence numbers or event ids to detect missed or duplicate updates.
- Reconnect with backoff and refresh the authoritative state after reconnect.
- Apply message size limits, rate limits, and abuse controls.
- Close or revoke subscriptions when access expires, a shift ends, or a participant loses authorization.

## 8. Notifications

The source specifies Firebase Cloud Messaging (FCM) with SMS fallback for dispatch reminders.

- At 60 minutes before the shift: ask the confirmed worker to respond with **On My Way**.
- At 30 minutes before: send preparation details and update the employer if the worker has not confirmed commute initiation.
- Use a notification scheduler with deduplication keys and delivery status tracking.
- Keep lock-screen notification text minimal; place private site details behind authenticated access.
- An SMS delivery receipt is not proof that a person has read a message.

## 9. Payment-provider webhooks

Payment callbacks must be treated as untrusted until verified.

1. Verify the provider's webhook signature against the raw request body.
2. Check event timestamp/replay protections as supported by the provider.
3. Store the provider event id and reject duplicate processing.
4. Apply a valid state transition inside a database transaction.
5. Record the provider reference and an immutable ledger entry.
6. Reconcile platform state against provider reports on a scheduled basis.

Do not accept payment success from the mobile client. Provider choice and available Nepal payment rails require validation.

## 10. Error response convention (proposed)

```json
{
  "error": {
    "code": "SHIFT_STATE_CONFLICT",
    "message": "This shift can no longer be updated in its current state.",
    "requestId": "req_example"
  }
}
```

Do not return internal service names, database messages, stack traces, secrets, or sensitive user existence details.
