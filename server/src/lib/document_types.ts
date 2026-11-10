export type DocumentType =
  | 'CITIZENSHIP'
  | 'NID'
  | 'PASSPORT'
  | 'DRIVING_LICENSE'
  | 'VOTER_ID';

export const documentTypes: DocumentType[] = [
  'CITIZENSHIP',
  'NID',
  'PASSPORT',
  'DRIVING_LICENSE',
  'VOTER_ID',
];

export const documentLabels: Record<DocumentType, string> = {
  CITIZENSHIP: 'Nepali Citizenship Certificate',
  NID: 'National Identity Card (NID)',
  PASSPORT: 'Nepali Passport',
  DRIVING_LICENSE: 'Driving Licence',
  VOTER_ID: 'Voter Identity Card',
};

/**
 * Two-sided cards need a back photo. The citizenship certificate and the
 * passport data page are captured front-only.
 */
export function documentRequiresBack(type: DocumentType): boolean {
  return type === 'NID' || type === 'DRIVING_LICENSE' || type === 'VOTER_ID';
}
