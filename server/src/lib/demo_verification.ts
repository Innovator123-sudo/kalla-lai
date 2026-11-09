import { errors } from './errors.js';
import {
  assertDocumentImage,
  assertSelfieImage,
  type ImageMetrics,
} from './image_checks.js';

export type DemoDocumentType =
  | 'CITIZENSHIP'
  | 'NID'
  | 'PASSPORT'
  | 'DRIVING_LICENSE'
  | 'VOTER_ID';

export const demoDocumentLabels: Record<DemoDocumentType, string> = {
  CITIZENSHIP: 'Nepali Citizenship Certificate',
  NID: 'National Identity Card (NID)',
  PASSPORT: 'Nepali Passport',
  DRIVING_LICENSE: 'Driving Licence',
  VOTER_ID: 'Voter Identity Card',
};

// Two-sided cards need a back photo; the passport data page and the citizenship
// certificate page are captured front-only.
export function demoRequiresBack(type: DemoDocumentType): boolean {
  return type === 'NID' || type === 'DRIVING_LICENSE' || type === 'VOTER_ID';
}

export interface DemoVerificationResult {
  documentType: DemoDocumentType;
  documentLabel: string;
  ocr: {
    fullName: string;
    documentNumber: string;
    dateOfBirth: string;
    address: string;
    confidence: number;
  };
  faceMatch: { score: number; liveness: boolean; passed: boolean };
  checks: {
    documentFront: ImageMetrics;
    documentBack: ImageMetrics | null;
    selfie: ImageMetrics;
  };
  stages: { key: string; label: string; status: 'passed' }[];
  decision: 'VERIFIED';
  demo: true;
  note: string;
}

const prefixes: Record<DemoDocumentType, string> = {
  CITIZENSHIP: 'CTZ',
  NID: 'NID',
  PASSPORT: 'PA',
  DRIVING_LICENSE: 'DL',
  VOTER_ID: 'VTR',
};

/// DEMO_MODE only: a synthetic stand-in for the production OCR + face-match
/// pipeline. The image-quality / document-likeness gates are real (they reject
/// illustrations, wrong-shaped documents, plain-text certificates and non-face
/// selfies), but the extracted fields and face-match score are synthetic. It
/// performs NO real OCR or biometric matching — production uses Veriff for that.
/// Never call this outside DEMO_MODE.
export function runDemoDocumentVerification(input: {
  documentType: DemoDocumentType;
  documentImage: string;
  documentBackImage?: string;
  selfieImage: string;
  fullName: string;
}): DemoVerificationResult {
  const needsBack = demoRequiresBack(input.documentType);
  if (needsBack && !input.documentBackImage) {
    throw errors.badRequest(
      'DOCUMENT_BACK_REQUIRED',
      `The ${demoDocumentLabels[input.documentType]} has two sides. Add a photo of the back as well.`,
    );
  }

  const documentFront = assertDocumentImage(input.documentImage, input.documentType, 'front');
  const documentBack = input.documentBackImage
    ? assertDocumentImage(input.documentBackImage, input.documentType, 'back')
    : null;
  const selfie = assertSelfieImage(input.selfieImage);

  const serial = Math.floor(100000000 + Math.random() * 900000000);
  const score = Math.round((0.93 + Math.random() * 0.05) * 100) / 100;

  return {
    documentType: input.documentType,
    documentLabel: demoDocumentLabels[input.documentType],
    ocr: {
      fullName: input.fullName,
      documentNumber: `${prefixes[input.documentType]}-${serial}`,
      dateOfBirth: '2056-04-12 BS',
      address: 'Kathmandu, Bagmati, Nepal',
      confidence: 0.97,
    },
    faceMatch: { score, liveness: true, passed: true },
    checks: { documentFront, documentBack, selfie },
    stages: [
      { key: 'IMAGE_QUALITY', label: 'Checking photo quality', status: 'passed' },
      { key: 'OCR_READ', label: 'Reading document (OCR)', status: 'passed' },
      { key: 'FACE_MATCH', label: 'Matching face to document', status: 'passed' },
      { key: 'LIVENESS', label: 'Liveness check', status: 'passed' },
      { key: 'DECISION', label: 'Verification decision', status: 'passed' },
    ],
    decision: 'VERIFIED',
    demo: true,
    note: 'Demo verification — photo quality and document-likeness checks are real; OCR and face-match are synthetic. Production uses Veriff for real biometric checks.',
  };
}