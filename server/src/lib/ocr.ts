import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
import { createOCREngine, type OCREngine } from 'tesseract-wasm';
import { errors } from './errors.js';
import { decodeDataUrl, downscaleTo, type DecodedImage } from './image_checks.js';

export interface OcrLanguageResult {
  text: string;
  confidence: number;
}

export interface OcrResult {
  nepali: OcrLanguageResult;
  english: OcrLanguageResult;
  combinedText: string;
  confidence: number;
}

type LoadableImage = Parameters<OCREngine['loadImage']>[0];

const here = path.dirname(fileURLToPath(import.meta.url));
const assetDirectories = [
  path.resolve(here, '../../assets/ocr'),
  path.resolve(process.cwd(), 'assets/ocr'),
];
const assetDirectory = assetDirectories.find((candidate) => existsSync(candidate));

let wasmBinaryPromise: Promise<Uint8Array> | null = null;
let languageModelPromises: Record<'nep' | 'eng', Promise<Uint8Array>> | null = null;

function ensureImageDataGlobal(): void {
  if (typeof (globalThis as Record<string, unknown>).ImageData !== 'undefined') return;
  class NodeImageData {
    constructor(
      public data: Uint8ClampedArray,
      public width: number,
      public height: number,
    ) {}
  }
  (globalThis as Record<string, unknown>).ImageData = NodeImageData;
}

function requireAsset(name: string): string {
  if (!assetDirectory) {
    throw errors.unavailable(
      'OCR_UNAVAILABLE',
      'The OCR runtime is not installed on this server. Contact support.',
    );
  }
  const file = path.join(assetDirectory, name);
  if (!existsSync(file)) {
    throw errors.unavailable(
      'OCR_UNAVAILABLE',
      'The OCR language data is missing on this server. Contact support.',
    );
  }
  return file;
}

function loadWasmBinary(): Promise<Uint8Array> {
  wasmBinaryPromise ??= readFile(requireAsset('tesseract-core.wasm')).then(
    (bytes) => new Uint8Array(bytes),
  );
  return wasmBinaryPromise;
}

function loadLanguageModels(): Record<'nep' | 'eng', Promise<Uint8Array>> {
  languageModelPromises ??= {
    nep: readFile(requireAsset('nep.traineddata.gz')).then(
      (bytes) => new Uint8Array(gunzipSync(bytes)),
    ),
    eng: readFile(requireAsset('eng.traineddata.gz')).then(
      (bytes) => new Uint8Array(gunzipSync(bytes)),
    ),
  };
  return languageModelPromises;
}

function toLoadableImage(image: DecodedImage): LoadableImage {
  const scaled = downscaleTo(image, 1800);
  return {
    data: new Uint8ClampedArray(
      scaled.data.buffer,
      scaled.data.byteOffset,
      scaled.data.byteLength,
    ),
    width: scaled.width,
    height: scaled.height,
  } as unknown as LoadableImage;
}

function recognize(engine: OCREngine, image: LoadableImage): OcrLanguageResult {
  engine.loadImage(image);
  try {
    const lines = engine.getTextBoxes('line');
    const text = lines
      .map((line) => line.text.trim())
      .filter(Boolean)
      .join('\n');
    const confidence =
      lines.length > 0
        ? lines.reduce((sum, line) => sum + line.confidence, 0) / lines.length
        : 0;
    return { text, confidence };
  } finally {
    engine.clearImage();
  }
}

/**
 * Reads a Nepali identity document with Tesseract's Nepali and English models.
 *
 * Tesseract only initializes the first language loaded into an engine, so the
 * two languages run in separate in-process WASM engines and the results are
 * combined. This avoids worker processes, which are not reliable in serverless
 * runtimes.
 */
export async function readDocumentText(dataUrl: string, field = 'Document photo'): Promise<OcrResult> {
  ensureImageDataGlobal();
  const decoded = decodeDataUrl(dataUrl, field);
  const image = toLoadableImage(decoded);

  let engineNep: OCREngine | null = null;
  let engineEng: OCREngine | null = null;
  try {
    const [wasmBinary, models] = await Promise.all([
      loadWasmBinary(),
      loadLanguageModels(),
    ]);
    engineNep = await createOCREngine({ wasmBinary });
    engineEng = await createOCREngine({ wasmBinary });
    engineNep.loadModel(await models.nep);
    engineEng.loadModel(await models.eng);

    const nepali = recognize(engineNep, image);
    const english = recognize(engineEng, image);
    return {
      nepali,
      english,
      combinedText: `${nepali.text}\n${english.text}`.trim(),
      confidence: Math.max(nepali.confidence, english.confidence),
    };
  } catch (error) {
    if (error instanceof Error && 'code' in error) throw error;
    throw errors.unavailable(
      'OCR_UNAVAILABLE',
      'The document reader could not start. Please try again in a moment.',
    );
  } finally {
    engineNep?.destroy();
    engineEng?.destroy();
  }
}
