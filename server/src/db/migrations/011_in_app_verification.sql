-- Real, self-hosted in-app identity verification (Nepali OCR + face match).
--
-- The old DEMO provider was synthetic and is no longer written. IN_APP is a
-- real pipeline: image-quality gates, Nepali/English OCR, selected-document
-- type validation, name matching, strict face matching and passive liveness.

ALTER TABLE identity_verifications
  DROP CONSTRAINT IF EXISTS identity_verifications_provider_check;
ALTER TABLE identity_verifications
  ADD CONSTRAINT identity_verifications_provider_check
  CHECK (provider IN ('VERIFF', 'DEMO', 'IN_APP'));
