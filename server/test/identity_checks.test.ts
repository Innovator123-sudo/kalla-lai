import { describe, expect, it } from 'vitest';
import {
  classifyDocument,
  compareNames,
  normalizeDigits,
  transliterateDevanagari,
} from '../src/lib/document_checks.js';
import { isFaceMatch } from '../src/lib/face_match.js';

describe('Nepali document checks', () => {
  it('normalizes Devanagari digits', () => {
    expect(normalizeDigits('नागरिकता नं. १२३४५६७८')).toBe('नागरिकता नं. 12345678');
    expect(normalizeDigits('२०५६-०४-१२')).toBe('2056-04-12');
  });

  it('transliterates Nepali names into Latin script', () => {
    const english = transliterateDevanagari('राम बहादुर श्रेष्ठ');
    expect(english.toLowerCase()).toContain('ram');
    expect(english.toLowerCase()).toContain('bahadur');
    expect(english.toLowerCase()).toContain('shrestha');
  });

  it('matches a profile name against the Nepali name on the document', () => {
    const match = compareNames('Ram Bahadur Shrestha', 'राम बहादुर श्रेष्ठ');
    expect(match.passed).toBe(true);
    expect(match.similarity).toBeGreaterThanOrEqual(0.75);
    expect(match.ocrNameEnglish.toLowerCase()).toContain('ram');
  });

  it('rejects a different person’s name', () => {
    const match = compareNames('Ram Bahadur Shrestha', 'सीता कुमारी थापा');
    expect(match.passed).toBe(false);
  });

  it('confirms the selected citizenship document', () => {
    const result = classifyDocument(
      'CITIZENSHIP',
      'नेपाल सरकार\nनागरिकता प्रमाणपत्र\nनाम: राम बहादुर श्रेष्ठ\nनागरिकता नं. १२३४५६७८',
    );
    expect(result.matched).toBe(true);
    expect(result.detectedType).toBe('CITIZENSHIP');
  });

  it('rejects a passport when the user selected citizenship', () => {
    const result = classifyDocument(
      'CITIZENSHIP',
      'REPUBLIC OF NEPAL\nPASSPORT\nPassport No: PA1234567\nMachine readable passport',
    );
    expect(result.matched).toBe(false);
    expect(result.detectedType).toBe('PASSPORT');
    expect(result.reason).toContain('Passport');
  });

  it('does not guess a document type from unrelated text', () => {
    const result = classifyDocument('NID', 'WELCOME TO KATHMANDU\nHAVE A NICE DAY');
    expect(result.matched).toBe(false);
    expect(result.detectedType).toBeNull();
  });
});

describe('strict face match thresholds', () => {
  it('accepts only close, high-similarity embeddings', () => {
    expect(isFaceMatch(0.91, 4.2)).toBe(true);
    expect(isFaceMatch(0.78, 7.9)).toBe(true);
  });

  it('rejects different people even when one signal looks plausible', () => {
    expect(isFaceMatch(0.44, 13.2)).toBe(false);
    expect(isFaceMatch(0.91, 12.0)).toBe(false);
    expect(isFaceMatch(0.74, 3.0)).toBe(false);
  });
});
