import { BadRequestException } from '@nestjs/common';

import type { CreateInvitationCommand, VersionedReasonCommand } from './user.types.js';

function object(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value))
    throw new BadRequestException('Request body must be an object');
  return value as Record<string, unknown>;
}
function exact(value: Record<string, unknown>, allowed: string[]): void {
  if (Object.keys(value).some((key) => !allowed.includes(key)))
    throw new BadRequestException('Request contains an unsupported field');
}
export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}
export function createInvitation(value: unknown): CreateInvitationCommand {
  const input = object(value);
  exact(input, ['email', 'displayName']);
  if (typeof input.email !== 'string' || typeof input.displayName !== 'string')
    throw new BadRequestException('email and displayName are required');
  const email = normalizeEmail(input.email);
  const displayName = input.displayName.trim();
  if (email.length === 0 || email.length > 255 || !email.includes('@') || displayName.length === 0)
    throw new BadRequestException('Invalid invitation input');
  return { displayName, email };
}
export function versionedReason(value: unknown): VersionedReasonCommand {
  const input = object(value);
  exact(input, ['expectedRowVersion', 'reason']);
  const version = input.expectedRowVersion;
  const reason = typeof input.reason === 'string' ? input.reason.trim() : '';
  if ((typeof version !== 'string' && typeof version !== 'number') || reason.length === 0)
    throw new BadRequestException('expectedRowVersion and reason are required');
  try {
    const expectedRowVersion = BigInt(version);
    if (expectedRowVersion < 1n) throw new Error();
    return { expectedRowVersion, reason };
  } catch {
    throw new BadRequestException('expectedRowVersion is invalid');
  }
}
export function redemptionToken(value: unknown): string {
  const input = object(value);
  exact(input, ['token']);
  if (typeof input.token !== 'string' || !/^[A-Za-z0-9_-]{43,}$/.test(input.token))
    throw new BadRequestException('INVITATION_INVALID');
  return input.token;
}
