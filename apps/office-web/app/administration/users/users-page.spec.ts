import { describe, expect, it } from 'vitest';
import { invitationLabel } from '../admin-client';

describe('invitation presentation', () => {
  it('presents persisted and derived invitation states without mutation', () => {
    expect(invitationLabel('PENDING', '2000-01-01T00:00:00Z')).toBe('Изтекла');
    expect(invitationLabel('CONSUMED', null)).toBe('Използвана');
    expect(invitationLabel('CANCELLED', null)).toBe('Отказана');
  });
});
