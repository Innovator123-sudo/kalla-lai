declare module 'jpeg-js' {
  export interface JpegDecodedImage {
    width: number;
    height: number;
    data: Uint8Array;
  }
  export interface JpegDecodeOptions {
    useTArray?: boolean;
    formatAsRGBA?: boolean;
    maxResolutionInMP?: number;
    tolerantDecoding?: boolean;
  }
  export function decode(
    data: Uint8Array | Buffer,
    options?: JpegDecodeOptions,
  ): JpegDecodedImage;
  export function encode(
    image: { width: number; height: number; data: Uint8Array | Buffer },
    quality?: number,
  ): { data: Buffer; width: number; height: number };
}

declare module 'pngjs' {
  export class PNG {
    width: number;
    height: number;
    data: Buffer;
    static sync: {
      read(buffer: Buffer | Uint8Array): PNG;
      write(png: PNG): Buffer;
    };
  }
}