import type { DocumentType } from './document_types.js';
import { documentLabels, documentRequiresBack } from './document_types.js';
import {
  assertDocumentImage,
  assertSelfieImage,
  type ImageMetrics,
} from './image_checks.js';
import { readDocumentText } from './ocr.js';
import {
  evaluateDocument,
  type DocumentClassification,
  type DocumentFields,
  type EnglishOcr,
  type NameMatch,
} from './document_checks.js';
import { matchDocumentFace, type FaceMatchResult } from './face_match.js';
import { AppError } from './errors.js';

export type StageStatus = 'passed' | 'failed' | 'skipped';

export interface VerificationStage {
  key: string;
  label: string;
  status: StageStatus;
  detail?: string;
}

export interface InAppVerificationResult {
  documentType: DocumentType;
  documentLabel: string;
  ocr: {
    fullName: string;
    fullNameEnglish: string;
    documentNumber: string;
    dateOfBirth: string;
    address: string;
    addressEnglish: string;
    confidence: number;
    english: EnglishOcr;
  };
  documentCheck: DocumentClassification;
  nameMatch: NameMatch;
  faceMatch: FaceMatchResult | null;
  checks: {
    documentFront: ImageMetrics | null;
    documentBack: ImageMetrics | null;
    selfie: ImageMetrics | null;
  };
  stages: VerificationStage[];
  decision: 'VERIFIED' | 'REJECTED';
  verified: boolean;
  rejectionCode: string | null;
  reason: string;
  note: string;
}

export interface InAppVerificationInput {
  documentType: DocumentType;
  documentImage: string;
  documentBackImage?: string;
  selfieImage: string;
  fullName: string;
}

const stageLabels: Record<string, string> = {
  IMAGE_QUALITY: 'Checking photo quality',
  OCR_READ: 'Reading the document (Nepali → English)',
  DOCUMENT_TYPE: 'Confirming the document type',
  NAME_MATCH: 'Matching the name on the document',
  FACE_MATCH: 'Matching your face to the document',
  LIVENESS: 'Liveness screening',
  DECISION: 'Verification decision',
};

const stageOrder = [
  'IMAGE_QUALITY',
  'OCR_READ',
  'DOCUMENT_TYPE',
  'NAME_MATCH',
  'FACE_MATCH',
  'LIVENESS',
  'DECISION',
] as const;

function initialStages(): VerificationStage[] {
  return stageOrder.map((key) => ({ key, label: stageLabels[key]!, status: 'skipped' }));
}

export interface InAppOutcome {
  result: InAppVerificationResult;
}

/**
 * Real, self-hosted identity verification:
 *
 *  1. image quality and document-likeness gates (no OCR yet),
 *  2. Nepali + English OCR,
 *  3. the selected document type must be present in the OCR text,
 *  4. the name on the document must match the profile name,
 *  5. only then a strict face embedding comparison and passive liveness
 *     screening run.
 *
 * Any failed stage stops the pipeline, marks the remaining stages as skipped,
 * and returns a rejection. The account becomes VERIFIED only when every stage
 * passes. Raw images and raw OCR text are never persisted.
 */
export async function runInAppVerification(
  input: InAppVerificationInput,
): Promise<InAppVerificationResult> {
  const stages = initialStages();
  const mark = (key: string, status: StageStatus, detail?: string) => {
    const stage = stages.find((candidate) => candidate.key === key);
    if (stage) {
      stage.status = status;
      stage.detail = detail;
    }
  };

  const label = documentLabels[input.documentType];
  const rejection = (
    code: string,
    reason: string,
    partial?: Partial<InAppVerificationResult>,
  ): InAppVerificationResult => ({
    documentType: input.documentType,
    documentLabel: label,
    ocr: {
      fullName: '',
      fullNameEnglish: '',
      documentNumber: '',
      dateOfBirth: '',
      address: '',
      addressEnglish: '',
      confidence: 0,
      english: {
        name: '',
        documentNumber: '',
        dateOfBirth: '',
        address: '',
        documentType: label,
        lines: [],
        summary: '',
      },
      ...partial?.ocr,
    },
    documentCheck:
      partial?.documentCheck ??
      ({
        selectedType: input.documentType,
        selectedLabel: label,
        detectedType: null,
        detectedLabel: null,
        matched: false,
        confidence: 0,
        scores: {
          CITIZENSHIP: 0,
          NID: 0,
          PASSPORT: 0,
          DRIVING_LICENSE: 0,
          VOTER_ID: 0,
        },
        evidence: [],
        reason: '',
      } satisfies DocumentClassification),
    nameMatch:
      partial?.nameMatch ??
      ({
        passed: false,
        similarity: 0,
        profileName: input.fullName,
        ocrName: '',
        ocrNameEnglish: '',
        matchedTokens: [],
        reason: '',
      } satisfies NameMatch),
    faceMatch: partial?.faceMatch ?? null,
    checks:
      partial?.checks ??
      ({
        documentFront: null,
        documentBack: null,
        selfie: null,
      } satisfies InAppVerificationResult['checks']),
    stages,
    decision: 'REJECTED',
    verified: false,
    rejectionCode: code,
    reason,
    note: 'Only the verification decision and the extracted document fields are stored. Photos are processed in memory and discarded. Passive single-image liveness screening is a screening step, not a guarantee against sophisticated spoofing.',
  });

  const needsBack = documentRequiresBack(input.documentType);
  if (needsBack && !input.documentBackImage) {
    mark(
      'IMAGE_QUALITY',
      'failed',
      `The ${label} has two sides. Add a photo of the back as well.`,
    );
    return rejection(
      'DOCUMENT_BACK_REQUIRED',
      `The ${label} has two sides. Add a photo of the back as well.`,
    );
  }

  // 1. Image quality and document-likeness gates.
  let documentFront: ImageMetrics;
  let documentBack: ImageMetrics | null = null;
  let selfie: ImageMetrics;
  try {
    documentFront = assertDocumentImage(input.documentImage, input.documentType, 'front');
    documentBack = input.documentBackImage
      ? assertDocumentImage(input.documentBackImage, input.documentType, 'back')
      : null;
    selfie = assertSelfieImage(input.selfieImage);
  } catch (error) {
    if (!(error instanceof AppError)) throw error;
    mark('IMAGE_QUALITY', 'failed', error.message);
    return rejection(error.code, error.message);
  }
  mark('IMAGE_QUALITY', 'passed', 'The photos are clear, well framed and look like real documents.');

  // 2. OCR: read the Nepali document and translate the extracted fields to
  //    English. Two traineddata models are used because Tesseract only loads
  //    the first language per engine.
  let evaluation: ReturnType<typeof evaluateDocument>;
  try {
    const ocr = await readDocumentText(input.documentImage, 'Document photo');
    const readableLines = `${ocr.nepali.text}\n${ocr.english.text}`
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length >= 2);
    if (readableLines.length < 3 || ocr.confidence < 0.35) {
      mark(
        'OCR_READ',
        'failed',
        'The text on the document could not be read clearly. Retake the photo with the whole document in focus.',
      );
      return rejection(
        'OCR_UNREADABLE',
        'The text on the document could not be read clearly. Retake the photo with the whole document in focus.',
      );
    }
    mark(
      'OCR_READ',
      'passed',
      `Read ${readableLines.length} lines in Nepali and English (${Math.round(ocr.confidence * 100)}% confidence).`,
    );
    evaluation = evaluateDocument({
      documentType: input.documentType,
      ocr,
      profileName: input.fullName,
    });
  } catch (error) {
    if (!(error instanceof AppError)) throw error;
    mark('OCR_READ', 'failed', error.message);
    return rejection(error.code, error.message);
  }

  const baseOcr = {
    fullName: evaluation.fields.fullName,
    fullNameEnglish: evaluation.fields.fullNameEnglish,
    documentNumber: evaluation.fields.documentNumber,
    dateOfBirth: evaluation.fields.dateOfBirth,
    address: evaluation.fields.address,
    addressEnglish: evaluation.fields.addressEnglish,
    confidence: evaluation.ocrConfidence,
    english: evaluation.english,
  };

  // 3. The document must really be the type the user selected.
  if (!evaluation.classification.matched) {
    const failure = evaluation.classification.reason;
    mark('DOCUMENT_TYPE', 'failed', failure);
    return rejection(
      evaluation.classification.detectedType
        ? 'DOCUMENT_TYPE_MISMATCH'
        : 'DOCUMENT_TYPE_UNREADABLE',
      failure,
      {
        ocr: baseOcr,
        documentCheck: evaluation.classification,
        nameMatch: evaluation.nameMatch,
        checks: { documentFront, documentBack, selfie },
      },
    );
  }
  mark(
    'DOCUMENT_TYPE',
    'passed',
    `Confirmed as ${label} from the document text.`,
  );

  // 4. The name on the document must match the profile name.
  if (!evaluation.nameMatch.passed) {
    mark('NAME_MATCH', 'failed', evaluation.nameMatch.reason);
    return rejection('NAME_MISMATCH', evaluation.nameMatch.reason, {
      ocr: baseOcr,
      documentCheck: evaluation.classification,
      nameMatch: evaluation.nameMatch,
      checks: { documentFront, documentBack, selfie },
    });
  }
  mark('NAME_MATCH', 'passed', evaluation.nameMatch.reason);

  // 5. Only now compare the document portrait with the selfie and run the
  //    passive liveness screening.
  let faceMatch: FaceMatchResult;
  try {
    faceMatch = await matchDocumentFace({
      documentImage: input.documentImage,
      selfieImage: input.selfieImage,
    });
  } catch (error) {
    if (!(error instanceof AppError)) throw error;
    mark('FACE_MATCH', 'failed', error.message);
    return rejection(error.code, error.message, {
      ocr: baseOcr,
      documentCheck: evaluation.classification,
      nameMatch: evaluation.nameMatch,
      checks: { documentFront, documentBack, selfie },
    });
  }

  if (!faceMatch.passed) {
    const livenessFailed = faceMatch.faceMatched && !faceMatch.livenessPassed;
    mark(
      'FACE_MATCH',
      livenessFailed ? 'passed' : 'failed',
      livenessFailed
        ? 'The selfie matches the portrait on the document.'
        : faceMatch.reason,
    );
    if (livenessFailed) {
      mark('LIVENESS', 'failed', faceMatch.reason);
    }
    return rejection(
      livenessFailed ? 'LIVENESS_FAILED' : 'FACE_MATCH_FAILED',
      faceMatch.reason,
      {
        ocr: baseOcr,
        documentCheck: evaluation.classification,
        nameMatch: evaluation.nameMatch,
        faceMatch,
        checks: { documentFront, documentBack, selfie },
      },
    );
  }
  mark(
    'FACE_MATCH',
    'passed',
    `The portrait on the document matches your selfie (${Math.round(faceMatch.score * 100)}% similarity).`,
  );
  mark(
    'LIVENESS',
    'passed',
    'The selfie passed passive liveness screening.',
  );
  mark('DECISION', 'passed', 'All checks passed. Identity verified.');

  return {
    documentType: input.documentType,
    documentLabel: label,
    ocr: baseOcr,
    documentCheck: evaluation.classification,
    nameMatch: evaluation.nameMatch,
    faceMatch,
    checks: { documentFront, documentBack, selfie },
    stages,
    decision: 'VERIFIED',
    verified: true,
    rejectionCode: null,
    reason: 'All checks passed. Your identity is verified.',
    note: 'Only the verification decision and the extracted document fields are stored. Photos are processed in memory and discarded. Passive single-image liveness screening is a screening step, not a guarantee against sophisticated spoofing.',
  };
}
