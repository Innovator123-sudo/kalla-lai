// Minimal local typings for tesseract-wasm. The package ships declarations but
// does not expose them through its package.json "exports" map, so TypeScript
// with NodeNext resolution cannot see them.
declare module 'tesseract-wasm' {
  export interface TextItem {
    rect: { left: number; top: number; right: number; bottom: number };
    flags: number;
    confidence: number;
    text: string;
  }

  export interface OCREngine {
    loadModel(model: Uint8Array | ArrayBuffer): void;
    loadImage(image: { data: Uint8ClampedArray; width: number; height: number }): void;
    getTextBoxes(unit: 'line' | 'word'): TextItem[];
    getText(progress?: (value: number) => void): string;
    clearImage(): void;
    destroy(): void;
  }

  export function createOCREngine(options: {
    wasmBinary?: Uint8Array | ArrayBuffer;
  }): Promise<OCREngine>;
}
