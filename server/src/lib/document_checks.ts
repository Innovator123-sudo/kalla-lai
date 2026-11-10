import type { OcrResult } from './ocr.js';
import {
  documentLabels,
  type DocumentType,
  documentTypes,
} from './document_types.js';

export interface DocumentClassification {
  selectedType: DocumentType;
  selectedLabel: string;
  detectedType: DocumentType | null;
  detectedLabel: string | null;
  matched: boolean;
  confidence: number;
  scores: Record<DocumentType, number>;
  evidence: string[];
  reason: string;
}

export interface DocumentFields {
  fullName: string;
  fullNameEnglish: string;
  documentNumber: string;
  dateOfBirth: string;
  address: string;
  addressEnglish: string;
  issueDate: string;
  expiryDate: string;
}

export interface EnglishOcr {
  name: string;
  documentNumber: string;
  dateOfBirth: string;
  address: string;
  documentType: string;
  lines: string[];
  summary: string;
}

export interface NameMatch {
  passed: boolean;
  similarity: number;
  profileName: string;
  ocrName: string;
  ocrNameEnglish: string;
  matchedTokens: string[];
  reason: string;
}

export interface DocumentEvaluation {
  classification: DocumentClassification;
  fields: DocumentFields;
  english: EnglishOcr;
  nameMatch: NameMatch;
  ocrConfidence: number;
}

const DEVANAGARI_DIGITS = '०१२३४५६७८९';

export function normalizeDigits(value: string): string {
  return value.replace(/[०-९]/g, (digit) => {
    const index = DEVANAGARI_DIGITS.indexOf(digit);
    return index >= 0 ? String(index) : digit;
  });
}

const independentVowels: Record<string, string> = {
  अ: 'a',
  आ: 'a',
  इ: 'i',
  ई: 'i',
  उ: 'u',
  ऊ: 'u',
  ऋ: 'ri',
  ए: 'e',
  ऐ: 'ai',
  ओ: 'o',
  औ: 'au',
  ॐ: 'om',
};

const vowelSigns: Record<string, string> = {
  'ा': 'a',
  'ि': 'i',
  'ी': 'i',
  'ु': 'u',
  'ू': 'u',
  'ृ': 'ri',
  'े': 'e',
  'ै': 'ai',
  'ो': 'o',
  'ौ': 'au',
  'ं': 'n',
  'ँ': 'n',
  'ः': 'h',
  '्': '',
};

const consonants: Record<string, string> = {
  क: 'k',
  ख: 'kh',
  ग: 'g',
  घ: 'gh',
  ङ: 'ng',
  च: 'ch',
  छ: 'chh',
  ज: 'j',
  झ: 'jh',
  ञ: 'ny',
  ट: 't',
  ठ: 'th',
  ड: 'd',
  ढ: 'dh',
  ण: 'n',
  त: 't',
  थ: 'th',
  द: 'd',
  ध: 'dh',
  न: 'n',
  प: 'p',
  फ: 'ph',
  ब: 'b',
  भ: 'bh',
  म: 'm',
  य: 'y',
  र: 'r',
  ल: 'l',
  व: 'v',
  श: 'sh',
  ष: 's',
  स: 's',
  ह: 'h',
  ळ: 'l',
  क्ष: 'ksh',
  त्र: 'tr',
  ज्ञ: 'gy',
  श्र: 'shr',
};

const devanagariPattern = /[\u0900-\u097F]/;
const latinPattern = /[A-Za-z]/;

/** Simple, name-oriented Devanagari transliteration. */
export function transliterateDevanagari(value: string): string {
  let output = '';
  for (let index = 0; index < value.length; index += 1) {
    const char = value[index];
    const next = value[index + 1];
    if (consonants[char]) {
      output += consonants[char];
      if (vowelSigns[next] === undefined) output += 'a';
      continue;
    }
    if (independentVowels[char]) {
      output += independentVowels[char];
      continue;
    }
    if (vowelSigns[char] !== undefined) {
      output += vowelSigns[char];
      continue;
    }
    if (char === '़') continue; // nukta
    if (char === '।') {
      output += '.';
      continue;
    }
    if (devanagariPattern.test(char)) continue;
    output += char;
  }
  return output;
}

export function normalizeNameText(value: string): string {
  const transliterated = devanagariPattern.test(value)
    ? transliterateDevanagari(value)
    : value;
  return transliterated
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/\b(?:mr|mrs|ms|miss|dr|shri|sri|shree|er|adv)\.?\b/g, ' ')
    .replace(/aa/g, 'a')
    .replace(/ee/g, 'i')
    .replace(/oo/g, 'u')
    .replace(/chh/g, 'ch')
    .replace(/sh/g, 's')
    .replace(/th/g, 't')
    .replace(/dh/g, 'd')
    .replace(/bh/g, 'b')
    .replace(/kh/g, 'k')
    .replace(/gh/g, 'g')
    .replace(/jh/g, 'j')
    .replace(/ph/g, 'f')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/(.)\1+/g, '$1')
    .trim()
    .replace(/\s+/g, ' ');
}

function levenshtein(a: string, b: string): number {
  if (a === b) return 0;
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;
  let previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let i = 1; i <= a.length; i += 1) {
    const current = [i];
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      current[j] = Math.min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost);
    }
    previous = current;
  }
  return previous[b.length];
}

function tokenSimilarity(a: string, b: string): number {
  const longest = Math.max(a.length, b.length);
  if (longest === 0) return 1;
  return 1 - levenshtein(a, b) / longest;
}

export function compareNames(profileName: string, ocrName: string): NameMatch {
  const profileTokens = normalizeNameText(profileName).split(' ').filter(Boolean);
  const ocrTokens = normalizeNameText(ocrName).split(' ').filter(Boolean);
  const empty: NameMatch = {
    passed: false,
    similarity: 0,
    profileName,
    ocrName,
    ocrNameEnglish: devanagariPattern.test(ocrName)
      ? transliterateDevanagari(ocrName).trim()
      : ocrName,
    matchedTokens: [],
    reason: '',
  };
  if (profileTokens.length === 0) {
    return { ...empty, reason: 'Add your full name to your profile before verifying.' };
  }
  if (ocrTokens.length === 0) {
    return { ...empty, reason: 'The name on the document could not be read. Retake the document photo.' };
  }

  const matchedTokens: string[] = [];
  let similaritySum = 0;
  for (const profileToken of profileTokens) {
    let best = 0;
    let bestToken = '';
    for (const ocrToken of ocrTokens) {
      const score = tokenSimilarity(profileToken, ocrToken);
      if (score > best) {
        best = score;
        bestToken = ocrToken;
      }
    }
    similaritySum += best;
    if (best >= 0.78) matchedTokens.push(bestToken);
  }

  const required =
    profileTokens.length === 1 ? 1 : Math.max(2, Math.ceil(profileTokens.length * 0.6));
  const similarity = similaritySum / profileTokens.length;
  const passed = matchedTokens.length >= required && similarity >= 0.75;
  return {
    passed,
    similarity: Math.round(similarity * 100) / 100,
    profileName,
    ocrName,
    ocrNameEnglish: devanagariPattern.test(ocrName)
      ? transliterateDevanagari(ocrName).trim()
      : ocrName,
    matchedTokens,
    reason: passed
      ? 'The name on the document matches your profile name.'
      : 'The name on the document does not match your profile name.',
  };
}

interface Keyword {
  term: string;
  weight: number;
}

const documentKeywords: Record<DocumentType, Keyword[]> = {
  CITIZENSHIP: [
    { term: 'नागरिकता प्रमाणपत्र', weight: 4 },
    { term: 'नागरिकता', weight: 2 },
    { term: 'citizenship certificate', weight: 4 },
    { term: 'citizenship', weight: 2 },
    { term: 'नागरिकता नं', weight: 2 },
  ],
  NID: [
    { term: 'राष्ट्रिय परिचय पत्र', weight: 4 },
    { term: 'राष्ट्रिय परिचय', weight: 3 },
    { term: 'परिचय पत्र', weight: 2 },
    { term: 'national identity card', weight: 4 },
    { term: 'national identity', weight: 3 },
    { term: 'national id', weight: 2 },
    { term: 'nid', weight: 2 },
  ],
  PASSPORT: [
    { term: 'राहदानी', weight: 4 },
    { term: 'passport', weight: 4 },
    { term: 'machine readable passport', weight: 4 },
    { term: 'republic of nepal', weight: 1 },
    { term: 'passport no', weight: 2 },
  ],
  DRIVING_LICENSE: [
    { term: 'सवारी चालक अनुमतिपत्र', weight: 5 },
    { term: 'चालक अनुमतिपत्र', weight: 4 },
    { term: 'driving licence', weight: 4 },
    { term: 'driving license', weight: 4 },
    { term: 'licence no', weight: 2 },
    { term: 'license no', weight: 2 },
  ],
  VOTER_ID: [
    { term: 'मतदाता परिचय पत्र', weight: 5 },
    { term: 'मतदाता', weight: 3 },
    { term: 'निर्वाचन आयोग', weight: 2 },
    { term: 'voter identity card', weight: 4 },
    { term: 'voter id', weight: 4 },
    { term: 'election commission', weight: 2 },
  ],
};

function countOccurrences(haystack: string, needle: string): number {
  if (!needle) return 0;
  let count = 0;
  let index = 0;
  while (count < 3) {
    const found = haystack.indexOf(needle, index);
    if (found < 0) break;
    count += 1;
    index = found + needle.length;
  }
  return count;
}

export function classifyDocument(
  selectedType: DocumentType,
  text: string,
): DocumentClassification {
  const normalized = text.toLowerCase().replace(/\s+/g, ' ');
  const scores = Object.fromEntries(
    documentTypes.map((type) => [type, 0]),
  ) as Record<DocumentType, number>;
  const evidence: string[] = [];

  for (const type of documentTypes) {
    for (const keyword of documentKeywords[type]) {
      const hits = countOccurrences(normalized, keyword.term.toLowerCase());
      if (hits > 0) {
        scores[type] += keyword.weight * Math.min(hits, 2);
        if (type === selectedType) evidence.push(keyword.term);
      }
    }
  }

  const ranked = documentTypes
    .map((type) => ({ type, score: scores[type] }))
    .sort((a, b) => b.score - a.score);
  const top = ranked[0];
  const second = ranked[1];
  const detectedType = top.score > 0 ? top.type : null;
  const confident = top.score >= 2 && (second.score === 0 || top.score > second.score);
  const matched = confident && top.type === selectedType;

  let reason: string;
  if (!detectedType || top.score === 0) {
    reason =
      'The document type could not be read. Make sure the whole document is visible, in focus and well lit.';
  } else if (!matched && top.type !== selectedType) {
    reason = `This looks like a ${documentLabels[top.type]}, but you selected ${documentLabels[selectedType]}. Choose the matching document type and try again.`;
  } else if (!confident) {
    reason =
      'The document type is not clear enough. Photograph the front of the document without glare and try again.';
  } else {
    reason = `The document matches the selected type (${documentLabels[selectedType]}).`;
  }

  return {
    selectedType,
    selectedLabel: documentLabels[selectedType],
    detectedType,
    detectedLabel: detectedType ? documentLabels[detectedType] : null,
    matched,
    confidence: Math.min(1, top.score / 8),
    scores,
    evidence: Array.from(new Set(evidence)).slice(0, 5),
    reason,
  };
}

const numberLabels: Record<DocumentType, string[]> = {
  CITIZENSHIP: [
    'नागरिकता नं',
    'नागरिकता नम्बर',
    'citizenship no',
    'citizenship number',
    'citizenship certificate no',
  ],
  NID: [
    'राष्ट्रिय परिचय पत्र नं',
    'परिचय पत्र नं',
    'national identity no',
    'nid no',
    'national id no',
  ],
  PASSPORT: ['राहदानी नं', 'राहदानी नम्बर', 'passport no', 'passport number'],
  DRIVING_LICENSE: [
    'सवारी चालक अनुमतिपत्र नं',
    'चालक अनुमतिपत्र नं',
    'licence no',
    'license no',
    'driving licence no',
    'driving license no',
  ],
  VOTER_ID: [
    'मतदाता नं',
    'मतदाता परिचय पत्र नं',
    'voter no',
    'voter id no',
    'voter number',
  ],
};

const fieldMarkers = [
  'नाम',
  'पूरा नाम',
  'नागरिकता नं',
  'राष्ट्रिय परिचय पत्र नं',
  'राहदानी नं',
  'जन्म मिति',
  'ठेगाना',
  'पता',
  'जारी मिति',
  'म्याद',
  'name',
  'full name',
  'citizenship no',
  'passport no',
  'licence no',
  'license no',
  'voter no',
  'date of birth',
  'address',
  'issue date',
  'expiry',
];

function linesOf(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

function cutAtNextMarker(value: string): string {
  let cut = value.length;
  for (const marker of fieldMarkers) {
    const index = value.toLowerCase().indexOf(marker.toLowerCase());
    if (index > 0 && index < cut) cut = index;
  }
  return value.slice(0, cut).trim();
}

function cleanValue(value: string): string {
  return cutAtNextMarker(
    value
      .replace(/^[\s:：.\-–—]+/, '')
      .replace(/[\s:：.\-–—]+$/, '')
      .replace(/\s+/g, ' '),
  );
}

function extractLabeledValue(text: string, labels: string[]): string {
  const lines = linesOf(text);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const lower = line.toLowerCase();
    for (const label of labels) {
      const position = lower.indexOf(label.toLowerCase());
      if (position < 0) continue;
      const after = line.slice(position + label.length);
      const value = cleanValue(after);
      if (value) return value;
      const next = lines[index + 1];
      if (next) return cleanValue(next);
    }
  }
  return '';
}

function cleanName(value: string): string {
  return value
    .replace(/^(?:full\s+name|name|पूरा\s+नाम|नाम)[\s:：.\-]*/i, '')
    .replace(/[|,;]+.*$/, '')
    .replace(/[^A-Za-z\u0900-\u097F .'-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractDocumentNumber(text: string, type: DocumentType): string {
  const labeled = extractLabeledValue(text, numberLabels[type]);
  const candidates = [labeled, extractLabeledValue(text, ['नं', 'नम्बर', 'no.', 'number'])];
  for (const candidate of candidates) {
    const normalized = normalizeDigits(candidate);
    const match = normalized.match(/[A-Z0-9][A-Z0-9\-\/]{3,}/i);
    if (match) return match[0].replace(/\s+/g, '');
  }
  return '';
}

function extractDate(text: string, labels: string[]): string {
  const value = extractLabeledValue(text, labels);
  const normalized = normalizeDigits(value);
  const match = normalized.match(
    /\b(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{4})\b/,
  );
  return match ? match[0] : '';
}

function extractFieldsFromText(text: string, type: DocumentType): DocumentFields {
  const name = cleanName(
    extractLabeledValue(text, ['पूरा नाम', 'नाम', 'full name', 'name']),
  );
  const documentNumber = extractDocumentNumber(text, type);
  const dateOfBirth =
    extractDate(text, ['जन्म मिति', 'जन्ममिति', 'date of birth', 'dob', 'birth date']) ||
    extractDate(text, ['जन्म']);
  const address = cleanValue(
    extractLabeledValue(text, ['ठेगाना', 'पता', 'address', 'permanent address', 'current address']),
  );
  const issueDate = extractDate(text, ['जारी मिति', 'issue date', 'date of issue']);
  const expiryDate = extractDate(text, [
    'म्याद',
    'expiry',
    'expiration',
    'valid until',
    'date of expiry',
  ]);
  return {
    fullName: name,
    fullNameEnglish: devanagariPattern.test(name)
      ? transliterateDevanagari(name).replace(/\s+/g, ' ').trim()
      : name,
    documentNumber,
    dateOfBirth,
    address,
    addressEnglish: devanagariPattern.test(address)
      ? transliterateDevanagari(address).replace(/\s+/g, ' ').trim()
      : address,
    issueDate,
    expiryDate,
  };
}

const labelTranslations: Array<[RegExp, string]> = [
  [/नेपाल सरकार/g, 'Government of Nepal'],
  [/नागरिकता प्रमाणपत्र/g, 'Citizenship Certificate'],
  [/नागरिकता/g, 'Citizenship'],
  [/राष्ट्रिय परिचय पत्र/g, 'National Identity Card'],
  [/राष्ट्रिय परिचय/g, 'National Identity'],
  [/परिचय पत्र/g, 'Identity Card'],
  [/राहदानी/g, 'Passport'],
  [/सवारी चालक अनुमतिपत्र/g, 'Driving Licence'],
  [/चालक अनुमतिपत्र/g, 'Driving Licence'],
  [/मतदाता परिचय पत्र/g, 'Voter Identity Card'],
  [/निर्वाचन आयोग/g, 'Election Commission'],
  [/जन्म मिति/g, 'Date of Birth'],
  [/जन्ममिति/g, 'Date of Birth'],
  [/ठेगाना/g, 'Address'],
  [/जारी मिति/g, 'Issue Date'],
  [/म्याद/g, 'Expiry'],
  [/नाम/g, 'Name'],
  [/नं/g, 'No.'],
  [/नम्बर/g, 'Number'],
  [/लिङ्ग/g, 'Gender'],
  [/राष्ट्रियता/g, 'Nationality'],
  [/पूरा नाम/g, 'Full Name'],
];

export function translateToEnglish(value: string): string {
  let translated = normalizeDigits(value);
  for (const [pattern, replacement] of labelTranslations) {
    translated = translated.replace(pattern, replacement);
  }
  if (devanagariPattern.test(translated)) {
    translated = transliterateDevanagari(translated);
  }
  return translated
    .replace(/[ \t]+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .trim();
}

function buildEnglishOcr(
  fields: DocumentFields,
  selectedType: DocumentType,
  rawText: string,
): EnglishOcr {
  const lines = linesOf(rawText)
    .map(translateToEnglish)
    .filter((line) => latinPattern.test(line))
    .slice(0, 20);
  const summaryParts = [
    fields.fullNameEnglish ? `Name: ${fields.fullNameEnglish}` : '',
    fields.documentNumber ? `Document No: ${normalizeDigits(fields.documentNumber)}` : '',
    fields.dateOfBirth ? `Date of Birth: ${fields.dateOfBirth}` : '',
    fields.addressEnglish ? `Address: ${fields.addressEnglish}` : '',
  ].filter(Boolean);
  return {
    name: fields.fullNameEnglish,
    documentNumber: normalizeDigits(fields.documentNumber),
    dateOfBirth: fields.dateOfBirth,
    address: fields.addressEnglish,
    documentType: documentLabels[selectedType],
    lines,
    summary:
      summaryParts.join(' | ') ||
      `The document was identified as ${documentLabels[selectedType]}, but no English field summary was available.`,
  };
}

function preferredValue(...values: string[]): string {
  return values.find((value) => value.trim().length > 0) ?? '';
}

/**
 * Validates the selected document type, extracts the identity fields, and
 * compares the document name with the profile name. Face matching runs only
 * after this returns a pass.
 */
export function evaluateDocument(input: {
  documentType: DocumentType;
  ocr: OcrResult;
  profileName: string;
}): DocumentEvaluation {
  const classification = classifyDocument(input.documentType, input.ocr.combinedText);
  const nepaliFields = extractFieldsFromText(input.ocr.nepali.text, input.documentType);
  const englishFields = extractFieldsFromText(input.ocr.english.text, input.documentType);
  const fullName = preferredValue(nepaliFields.fullName, englishFields.fullName);
  const documentNumber = preferredValue(
    nepaliFields.documentNumber,
    englishFields.documentNumber,
  );
  const dateOfBirth = preferredValue(nepaliFields.dateOfBirth, englishFields.dateOfBirth);
  const address = preferredValue(nepaliFields.address, englishFields.address);
  const issueDate = preferredValue(nepaliFields.issueDate, englishFields.issueDate);
  const expiryDate = preferredValue(nepaliFields.expiryDate, englishFields.expiryDate);
  const fields: DocumentFields = {
    fullName,
    fullNameEnglish: devanagariPattern.test(fullName)
      ? transliterateDevanagari(fullName).replace(/\s+/g, ' ').trim()
      : fullName,
    documentNumber,
    dateOfBirth,
    address,
    addressEnglish: devanagariPattern.test(address)
      ? transliterateDevanagari(address).replace(/\s+/g, ' ').trim()
      : address,
    issueDate,
    expiryDate,
  };
  const nameMatch = compareNames(input.profileName, fields.fullName);
  return {
    classification,
    fields,
    english: buildEnglishOcr(fields, input.documentType, input.ocr.combinedText),
    nameMatch,
    ocrConfidence: Math.round(input.ocr.confidence * 100) / 100,
  };
}
