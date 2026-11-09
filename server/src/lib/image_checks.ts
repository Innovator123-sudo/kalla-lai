import { decode as jpegDecode } from 'jpeg-js';
import { PNG } from 'pngjs';
import { errors } from './errors.js';
import type { DemoDocumentType } from './demo_verification.js';

export interface ImageMetrics {
  width: number;
  height: number;
  aspect: number;
  sharpness: number;
  flatRatio: number;
  meanSaturation: number;
  colorRichness: number;
  skinRatio: number;
}

interface RgbaImage {
  width: number;
  height: number;
  data: Uint8Array | Uint8ClampedArray | Buffer;
}

const MAX_SIDE = 320;

function decodeDataUrl(dataUrl: string, field: string): RgbaImage {
  const match = /^data:([^;]+);base64,([\s\S]*)$/.exec(dataUrl);
  const base64 = match
    ? match[2]
    : dataUrl.includes(',')
      ? dataUrl.slice(dataUrl.indexOf(',') + 1)
      : dataUrl;
  let bytes: Buffer;
  try {
    bytes = Buffer.from(base64, 'base64');
  } catch {
    throw errors.badRequest('INVALID_IMAGE', `${field} could not be read.`);
  }
  if (bytes.length < 200) {
    throw errors.badRequest('INVALID_IMAGE', `${field} is empty or unreadable. Retake the photo.`);
  }
  if (bytes.length > 12 * 1024 * 1024) {
    throw errors.badRequest('FILE_TOO_LARGE', `${field} is too large. Use a photo under 12 MB.`);
  }
  const isJpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const isPng =
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47;
  if (isJpeg) {
    try {
      const img = jpegDecode(bytes, { useTArray: true, maxResolutionInMP: 8 });
      return { width: img.width, height: img.height, data: img.data };
    } catch {
      throw errors.badRequest('INVALID_IMAGE', `${field} is not a readable JPEG photo.`);
    }
  }
  if (isPng) {
    try {
      const img = PNG.sync.read(bytes);
      return { width: img.width, height: img.height, data: img.data };
    } catch {
      throw errors.badRequest('INVALID_IMAGE', `${field} is not a readable PNG photo.`);
    }
  }
  throw errors.badRequest('INVALID_IMAGE', `${field} must be a JPEG or PNG photo.`);
}

function downscale(img: RgbaImage): RgbaImage {
  const scale = Math.min(1, MAX_SIDE / Math.max(img.width, img.height));
  if (scale >= 1) return img;
  const width = Math.max(1, Math.round(img.width * scale));
  const height = Math.max(1, Math.round(img.height * scale));
  const out = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y++) {
    const sy = Math.min(img.height - 1, Math.floor(y / scale));
    for (let x = 0; x < width; x++) {
      const sx = Math.min(img.width - 1, Math.floor(x / scale));
      const src = (sy * img.width + sx) * 4;
      const dst = (y * width + x) * 4;
      out[dst] = img.data[src];
      out[dst + 1] = img.data[src + 1];
      out[dst + 2] = img.data[src + 2];
      out[dst + 3] = img.data[src + 3];
    }
  }
  return { width, height, data: out };
}

function computeMetrics(img: RgbaImage): ImageMetrics {
  const { width, height, data } = img;
  const gray = new Float32Array(width * height);
  for (let i = 0; i < width * height; i++) {
    const p = i * 4;
    gray[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2];
  }
  let lapSum = 0;
  let lapSq = 0;
  let flat = 0;
  let satSum = 0;
  let skin = 0;
  let n = 0;
  const buckets = new Set<number>();
  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      const i = y * width + x;
      const g0 = gray[i];
      const lap = 4 * g0 - gray[i - 1] - gray[i + 1] - gray[i - width] - gray[i + width];
      lapSum += lap;
      lapSq += lap * lap;
      let mn = g0;
      let mx = g0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const v = gray[i + dy * width + dx];
          if (v < mn) mn = v;
          if (v > mx) mx = v;
        }
      }
      if (mx - mn < 8) flat++;
      const p = i * 4;
      const r = data[p];
      const g = data[p + 1];
      const b = data[p + 2];
      const cmax = Math.max(r, g, b);
      const cmin = Math.min(r, g, b);
      satSum += cmax === 0 ? 0 : (cmax - cmin) / cmax;
      buckets.add(((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3));
      // YCbCr skin cluster — inclusive of a wide range of skin tones.
      const cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
      const cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
      if (g0 > 50 && cb >= 77 && cb <= 127 && cr >= 133 && cr <= 177) skin++;
      n++;
    }
  }
  const sharpness = n > 0 ? lapSq / n - (lapSum / n) ** 2 : 0;
  return {
    width: img.width,
    height: img.height,
    aspect: img.width / img.height,
    sharpness,
    flatRatio: n > 0 ? flat / n : 0,
    meanSaturation: n > 0 ? satSum / n : 0,
    colorRichness: n > 0 ? buckets.size / n : 0,
    skinRatio: n > 0 ? skin / n : 0,
  };
}

// Colourful flat fills (cartoons / anime) differ from photographs, which carry
// sensor noise and natural gradients. Low-saturation paper scans are not flagged.
function looksLikeIllustration(m: ImageMetrics): boolean {
  return m.meanSaturation > 0.35 && m.flatRatio > 0.4;
}

const landscapeCards: DemoDocumentType[] = ['NID', 'DRIVING_LICENSE', 'VOTER_ID', 'PASSPORT'];

export function analyzeImage(dataUrl: string, field = 'Photo'): ImageMetrics {
  return computeMetrics(downscale(decodeDataUrl(dataUrl, field)));
}

export function assertDocumentImage(
  dataUrl: string,
  documentType: DemoDocumentType,
  side: 'front' | 'back',
): ImageMetrics {
  const img = decodeDataUrl(dataUrl, 'Document photo');
  const minSide = Math.min(img.width, img.height);
  if (minSide < 400) {
    throw errors.badRequest(
      'DOCUMENT_REJECTED',
      'The document photo is too small. Capture the whole document clearly (at least 400px on the shortest side).',
    );
  }
  const m = computeMetrics(downscale(img));
  if (m.sharpness < 12) {
    throw errors.badRequest(
      'DOCUMENT_REJECTED',
      'The document photo looks blurry. Hold the camera steady, refocus and try again.',
    );
  }
  if (looksLikeIllustration(m)) {
    throw errors.badRequest(
      'DOCUMENT_REJECTED',
      'This looks like a drawing or illustration, not a photo of a real identity document.',
    );
  }
  const landscape = landscapeCards.includes(documentType);
  if (landscape && (m.aspect < 1.15 || m.aspect > 2.3)) {
    throw errors.badRequest(
      'DOCUMENT_REJECTED',
      'This document is a horizontal card or page. Frame it landscape (wider than tall) and try again.',
    );
  }
  if (!landscape && (m.aspect < 0.45 || m.aspect > 1.3)) {
    throw errors.badRequest(
      'DOCUMENT_REJECTED',
      'The citizenship certificate is a vertical page. Frame it portrait (taller than wide) and try again.',
    );
  }
  if (side === 'front' && m.skinRatio < 0.006) {
    throw errors.badRequest(
      'DOCUMENT_REJECTED',
      'No portrait photo was detected on the document. Plain-text documents such as birth certificates are not accepted.',
    );
  }
  return m;
}

export function assertSelfieImage(dataUrl: string): ImageMetrics {
  const img = decodeDataUrl(dataUrl, 'Selfie');
  if (Math.min(img.width, img.height) < 300) {
    throw errors.badRequest(
      'SELFIE_REJECTED',
      'The selfie is too small. Capture a clear photo of your face (at least 300px).',
    );
  }
  const m = computeMetrics(downscale(img));
  if (m.sharpness < 10) {
    throw errors.badRequest('SELFIE_REJECTED', 'The selfie looks blurry. Hold steady and try again.');
  }
  if (looksLikeIllustration(m)) {
    throw errors.badRequest(
      'SELFIE_REJECTED',
      'The selfie looks like a drawing or anime image. Use a real photo of your face.',
    );
  }
  if (m.skinRatio < 0.04) {
    throw errors.badRequest(
      'SELFIE_REJECTED',
      'No face was detected. Fill the frame with your face in good light and try again.',
    );
  }
  return m;
}