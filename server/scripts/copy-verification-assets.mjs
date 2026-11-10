import { copyFile, mkdir, access } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Copies the binary verification assets out of node_modules into `assets/`
 * so they can be committed and bundled with the serverless function.
 *
 * Vercel does not trace files that are only referenced through runtime paths
 * (Tesseract traineddata, TensorFlow WASM kernels, Human face models), so the
 * deploy must include them explicitly. Keeping a committed copy also makes a
 * fresh checkout runnable without a separate asset-fetch step.
 */

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const modules = path.join(root, 'node_modules');

const copies = [
  // Tesseract WASM core (fast + fallback) and Nepali/English traineddata.
  ['tesseract-wasm/dist/tesseract-core.wasm', 'assets/ocr/tesseract-core.wasm'],
  ['tesseract-wasm/dist/tesseract-core-fallback.wasm', 'assets/ocr/tesseract-core-fallback.wasm'],
  ['@tesseract.js-data/nep/4.0.0/nep.traineddata.gz', 'assets/ocr/nep.traineddata.gz'],
  ['@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz', 'assets/ocr/eng.traineddata.gz'],

  // TensorFlow.js WASM backend kernels.
  ['@tensorflow/tfjs-backend-wasm/dist/tfjs-backend-wasm.wasm', 'assets/tfjs-wasm/tfjs-backend-wasm.wasm'],
  ['@tensorflow/tfjs-backend-wasm/dist/tfjs-backend-wasm-simd.wasm', 'assets/tfjs-wasm/tfjs-backend-wasm-simd.wasm'],
  [
    '@tensorflow/tfjs-backend-wasm/dist/tfjs-backend-wasm-threaded-simd.wasm',
    'assets/tfjs-wasm/tfjs-backend-wasm-threaded-simd.wasm',
  ],

  // Human face detector / mesh / recognition / passive liveness models.
  // The .cjs extension is deliberate: this bundle is CommonJS and the server
  // package is `"type": "module"`, so a .js copy would be treated as ESM and
  // could not be loaded with require() in the serverless runtime.
  ['@vladmandic/human/dist/human.node-wasm.js', 'assets/human/human.node-wasm.cjs'],
  ['@vladmandic/human/models/blazeface.json', 'assets/face-models/blazeface.json'],
  ['@vladmandic/human/models/blazeface.bin', 'assets/face-models/blazeface.bin'],
  ['@vladmandic/human/models/facemesh.json', 'assets/face-models/facemesh.json'],
  ['@vladmandic/human/models/facemesh.bin', 'assets/face-models/facemesh.bin'],
  ['@vladmandic/human/models/faceres.json', 'assets/face-models/faceres.json'],
  ['@vladmandic/human/models/faceres.bin', 'assets/face-models/faceres.bin'],
  ['@vladmandic/human/models/antispoof.json', 'assets/face-models/antispoof.json'],
  ['@vladmandic/human/models/antispoof.bin', 'assets/face-models/antispoof.bin'],
  ['@vladmandic/human/models/liveness.json', 'assets/face-models/liveness.json'],
  ['@vladmandic/human/models/liveness.bin', 'assets/face-models/liveness.bin'],
];

let copied = 0;
for (const [source, target] of copies) {
  const from = path.join(modules, source);
  const to = path.join(root, target);
  try {
    await access(from);
  } catch {
    throw new Error(
      `Missing verification asset source: ${source}. Run npm install before copying assets.`,
    );
  }
  await mkdir(path.dirname(to), { recursive: true });
  await copyFile(from, to);
  copied += 1;
}

console.log(`Copied ${copied} verification assets to ${path.join(root, 'assets')}`);
