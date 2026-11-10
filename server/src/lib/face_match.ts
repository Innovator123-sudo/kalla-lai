import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import type { Human as HumanInstance, Config as HumanConfig } from '@vladmandic/human';
// Static imports guarantee the serverless bundler traces the TFJS runtime that
// the Human node-wasm bundle requires dynamically.
import '@tensorflow/tfjs-core';
import '@tensorflow/tfjs-converter';
import '@tensorflow/tfjs-backend-wasm';
import { errors } from './errors.js';
import { decodeDataUrl, downscaleTo } from './image_checks.js';

export interface FaceMatchResult {
  passed: boolean;
  faceMatched: boolean;
  score: number;
  distance: number;
  threshold: number;
  documentFaceCount: number;
  selfieFaceCount: number;
  livenessPassed: boolean;
  livenessScore: number;
  realScore: number;
  reason: string;
}

const FACE_MATCH_MIN_COSINE = 0.75;
const FACE_MATCH_MAX_DISTANCE = 8;

const here = path.dirname(fileURLToPath(import.meta.url));
const assetRoots = [
  path.resolve(here, '../../assets'),
  path.resolve(process.cwd(), 'assets'),
];
const assetRoot = assetRoots.find((candidate) => existsSync(path.join(candidate, 'face-models')));

const require = createRequire(import.meta.url);
let HumanConstructor: typeof HumanInstance | null = null;

/**
 * The package's "exports" map does not expose the Node WASM entry point, so the
 * copy script places the self-contained node-wasm bundle in `assets/human/`.
 * That file is included with the serverless function and only requires the
 * TensorFlow.js packages imported statically above.
 */
function loadHumanConstructor(assetRoot: string): typeof HumanInstance {
  if (HumanConstructor) return HumanConstructor;
  const bundle = path.join(assetRoot, 'human', 'human.node-wasm.js');
  if (!existsSync(bundle)) {
    throw errors.unavailable(
      'FACE_CHECK_UNAVAILABLE',
      'The face verification runtime is not installed on this server. Contact support.',
    );
  }
  const module = require(bundle) as {
    default?: typeof HumanInstance;
    Human?: typeof HumanInstance;
  };
  HumanConstructor = (module.default ?? module.Human) as typeof HumanInstance;
  return HumanConstructor;
}

let fetchShimInstalled = false;

function installFileFetchShim(): void {
  if (fetchShimInstalled) return;
  fetchShimInstalled = true;
  const originalFetch = globalThis.fetch;
  if (typeof originalFetch !== 'function') return;
  globalThis.fetch = async (
    input: string | URL | { url: string },
    init?: RequestInit,
  ) => {
    const url =
      typeof input === 'string'
        ? input
        : input instanceof URL
          ? input.href
          : input.url;
    if (url.startsWith('file://')) {
      const file = fileURLToPath(url);
      const bytes = await readFile(file);
      return new Response(new Uint8Array(bytes), {
        status: 200,
        headers: {
          'content-type': file.endsWith('.json')
            ? 'application/json'
            : 'application/octet-stream',
        },
      });
    }
    return originalFetch(input as string | URL | Request, init);
  };
}

function requireAssets(): { faceModels: string; wasm: string } {
  if (!assetRoot) {
    throw errors.unavailable(
      'FACE_CHECK_UNAVAILABLE',
      'The face verification runtime is not installed on this server. Contact support.',
    );
  }
  const faceModels = path.join(assetRoot, 'face-models');
  const wasm = path.join(assetRoot, 'tfjs-wasm');
  const required = [
    path.join(faceModels, 'blazeface.json'),
    path.join(faceModels, 'blazeface.bin'),
    path.join(faceModels, 'facemesh.json'),
    path.join(faceModels, 'facemesh.bin'),
    path.join(faceModels, 'faceres.json'),
    path.join(faceModels, 'faceres.bin'),
    path.join(faceModels, 'liveness.json'),
    path.join(faceModels, 'liveness.bin'),
    path.join(faceModels, 'antispoof.json'),
    path.join(faceModels, 'antispoof.bin'),
    path.join(wasm, 'tfjs-backend-wasm.wasm'),
  ];
  if (!required.every((file) => existsSync(file))) {
    throw errors.unavailable(
      'FACE_CHECK_UNAVAILABLE',
      'The face verification models are missing on this server. Contact support.',
    );
  }
  return { faceModels, wasm };
}

function humanConfig(faceModels: string, wasm: string): Partial<HumanConfig> {
  return {
    backend: 'wasm',
    wasmPath: pathToFileURL(wasm + path.sep).href,
    wasmPlatformFetch: true,
    modelBasePath: pathToFileURL(faceModels + path.sep).href,
    debug: false,
    async: false,
    warmup: 'none',
    cacheModels: false,
    filter: { enabled: false, flip: false },
    face: {
      enabled: true,
      detector: {
        enabled: true,
        rotation: false,
        maxDetected: 3,
        minConfidence: 0.3,
        minSize: 36,
        iouThreshold: 0.3,
      },
      mesh: { enabled: true },
      description: { enabled: true },
      iris: { enabled: false },
      emotion: { enabled: false },
      antispoof: { enabled: true },
      liveness: { enabled: true },
    },
    body: { enabled: false },
    hand: { enabled: false },
    object: { enabled: false },
    gesture: { enabled: false },
  };
}

let humanPromise: Promise<HumanInstance> | null = null;
let faceQueue: Promise<unknown> = Promise.resolve();

function getHuman(): Promise<HumanInstance> {
  if (!humanPromise) {
    const assets = requireAssets();
    installFileFetchShim();
    const Human = loadHumanConstructor(assetRoot!);
    const human = new Human(humanConfig(assets.faceModels, assets.wasm));
    humanPromise = human
      .load()
      .then(() => human)
      .catch((error: unknown) => {
        humanPromise = null;
        throw error;
      });
  }
  return humanPromise;
}

function withFaceLock<T>(action: () => Promise<T>): Promise<T> {
  const run = faceQueue.then(action, action);
  faceQueue = run.then(
    () => undefined,
    () => undefined,
  );
  return run;
}

interface DetectedFace {
  score: number;
  box: [number, number, number, number];
  embedding: number[];
  live: number;
  real: number;
  area: number;
}

function detectLargestFace(
  faces: Array<{
    score: number;
    box: [number, number, number, number];
    embedding: number[];
    live?: number;
    real?: number;
  }>,
): DetectedFace | null {
  const significant = faces
    .filter((face) => Array.isArray(face.box) && face.box.length >= 4)
    .map((face) => ({
      score: Number(face.score) || 0,
      box: face.box,
      embedding: Array.isArray(face.embedding) ? face.embedding.map(Number) : [],
      live: Number(face.live) || 0,
      real: Number(face.real) || 0,
      area: Math.max(0, face.box[2]) * Math.max(0, face.box[3]),
    }))
    .filter((face) => face.embedding.length > 0)
    .sort((a, b) => b.area - a.area);
  return significant[0] ?? null;
}

function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0;
  let normA = 0;
  let normB = 0;
  const length = Math.min(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    dot += a[index] * b[index];
    normA += a[index] * a[index];
    normB += b[index] * b[index];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

function euclideanDistance(a: number[], b: number[]): number {
  let sum = 0;
  const length = Math.min(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    const difference = a[index] - b[index];
    sum += difference * difference;
  }
  return Math.sqrt(sum);
}

export function isFaceMatch(score: number, distance: number): boolean {
  return score >= FACE_MATCH_MIN_COSINE && distance <= FACE_MATCH_MAX_DISTANCE;
}

function tensorFromDataUrl(
  human: HumanInstance,
  dataUrl: string,
  field: string,
) {
  const decoded = decodeDataUrl(dataUrl, field);
  const scaled = downscaleTo(decoded, 1600);
  const pixels = new Float32Array(scaled.width * scaled.height * 3);
  for (let source = 0, target = 0; source < scaled.data.length; source += 4, target += 3) {
    pixels[target] = scaled.data[source];
    pixels[target + 1] = scaled.data[source + 1];
    pixels[target + 2] = scaled.data[source + 2];
  }
  return human.tf.tensor4d(pixels, [1, scaled.height, scaled.width, 3], 'float32');
}

/**
 * Compares the portrait on the document with the selfie and runs Human's
 * passive single-image liveness/anti-spoof screening. This is called only after
 * the document type and OCR name checks have passed.
 */
export async function matchDocumentFace(input: {
  documentImage: string;
  selfieImage: string;
}): Promise<FaceMatchResult> {
  return withFaceLock(async () => {
    let human: HumanInstance;
    try {
      human = await getHuman();
    } catch (error) {
      if (error instanceof Error && 'code' in error) throw error;
      throw errors.unavailable(
        'FACE_CHECK_UNAVAILABLE',
        'The face verification engine could not start. Please try again in a moment.',
      );
    }

    let documentTensor: ReturnType<typeof tensorFromDataUrl> | null = null;
    let selfieTensor: ReturnType<typeof tensorFromDataUrl> | null = null;
    try {
      documentTensor = tensorFromDataUrl(human, input.documentImage, 'Document photo');
      selfieTensor = tensorFromDataUrl(human, input.selfieImage, 'Selfie');

      const documentResult = await human.detect(documentTensor);
      const selfieResult = await human.detect(selfieTensor);
      const documentFaces = documentResult.face as unknown as Array<{
        score: number;
        box: [number, number, number, number];
        embedding: number[];
        live?: number;
        real?: number;
      }>;
      const selfieFaces = selfieResult.face as unknown as Array<{
        score: number;
        box: [number, number, number, number];
        embedding: number[];
        live?: number;
        real?: number;
      }>;

      const documentFace = detectLargestFace(documentFaces);
      const selfieFace = detectLargestFace(selfieFaces);
      const documentFaceCount = documentFaces.filter((face) => face.embedding?.length).length;
      const selfieFaceCount = selfieFaces.filter((face) => face.embedding?.length).length;

      if (!documentFace) {
        return {
          passed: false,
          faceMatched: false,
          score: 0,
          distance: 0,
          threshold: FACE_MATCH_MIN_COSINE,
          documentFaceCount,
          selfieFaceCount,
          livenessPassed: false,
          livenessScore: 0,
          realScore: 0,
          reason:
            'No portrait photo could be found on the document. Make sure the document photo is clear and the whole document is visible.',
        };
      }
      if (!selfieFace) {
        return {
          passed: false,
          faceMatched: false,
          score: 0,
          distance: 0,
          threshold: FACE_MATCH_MIN_COSINE,
          documentFaceCount,
          selfieFaceCount,
          livenessPassed: false,
          livenessScore: 0,
          realScore: 0,
          reason:
            'No face was detected in the selfie. Face the camera in good light and keep your whole face visible.',
        };
      }
      if (selfieFaceCount > 1) {
        return {
          passed: false,
          faceMatched: false,
          score: 0,
          distance: 0,
          threshold: FACE_MATCH_MIN_COSINE,
          documentFaceCount,
          selfieFaceCount,
          livenessPassed: false,
          livenessScore: 0,
          realScore: 0,
          reason: 'More than one face was detected in the selfie. Take a selfie on your own.',
        };
      }

      const score = cosineSimilarity(documentFace.embedding, selfieFace.embedding);
      const distance = euclideanDistance(documentFace.embedding, selfieFace.embedding);
      const faceMatched = isFaceMatch(score, distance);
      const livenessPassed = selfieFace.live >= 0.35 && selfieFace.real >= 0.2;

      if (!faceMatched) {
        return {
          passed: false,
          faceMatched: false,
          score: Math.round(score * 100) / 100,
          distance: Math.round(distance * 100) / 100,
          threshold: FACE_MATCH_MIN_COSINE,
          documentFaceCount,
          selfieFaceCount,
          livenessPassed,
          livenessScore: Math.round(selfieFace.live * 100) / 100,
          realScore: Math.round(selfieFace.real * 100) / 100,
          reason:
            'The selfie does not match the portrait on the document. Use a clear photo of your own face, not someone else’s.',
        };
      }
      if (!livenessPassed) {
        return {
          passed: false,
          faceMatched: true,
          score: Math.round(score * 100) / 100,
          distance: Math.round(distance * 100) / 100,
          threshold: FACE_MATCH_MIN_COSINE,
          documentFaceCount,
          selfieFaceCount,
          livenessPassed,
          livenessScore: Math.round(selfieFace.live * 100) / 100,
          realScore: Math.round(selfieFace.real * 100) / 100,
          reason:
            'The selfie did not pass the passive liveness screening. Use a fresh, well-lit photo of your face and do not photograph a screen or a printed photo.',
        };
      }

      return {
        passed: true,
        faceMatched: true,
        score: Math.round(score * 100) / 100,
        distance: Math.round(distance * 100) / 100,
        threshold: FACE_MATCH_MIN_COSINE,
        documentFaceCount,
        selfieFaceCount,
        livenessPassed,
        livenessScore: Math.round(selfieFace.live * 100) / 100,
        realScore: Math.round(selfieFace.real * 100) / 100,
        reason: 'The selfie matches the portrait on the document.',
      };
    } finally {
      documentTensor?.dispose();
      selfieTensor?.dispose();
      human.tf.disposeVariables?.();
    }
  });
}
