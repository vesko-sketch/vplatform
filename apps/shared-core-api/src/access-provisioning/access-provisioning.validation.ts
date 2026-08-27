import { BadRequestException } from '@nestjs/common';

import type { EndRelationshipCommand, ValidityCommand } from './access-provisioning.types.js';

type Body = Record<string, unknown>;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function body(value: unknown, allowed: readonly string[]): Body {
  if (value === null || typeof value !== 'object' || Array.isArray(value))
    throw new BadRequestException('Request body must be an object');
  const record = value as Body;
  const unexpected = Object.keys(record).find((key) => !allowed.includes(key));
  if (unexpected !== undefined) throw new BadRequestException(`Unknown field: ${unexpected}`);
  return record;
}

function rowVersion(record: Body, required: boolean): bigint | undefined {
  const value = record.expectedRowVersion;
  if (value === undefined && !required) return undefined;
  if ((typeof value !== 'string' && typeof value !== 'number') || !/^[1-9]\d*$/.test(String(value)))
    throw new BadRequestException('expectedRowVersion must be a positive integer');
  return BigInt(value);
}

function date(record: Body, key: 'validFrom' | 'validTo'): string | null {
  const value = record[key];
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string' || !datePattern.test(value))
    throw new BadRequestException(`${key} must be an ISO date`);
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value)
    throw new BadRequestException(`${key} must be a valid ISO date`);
  return value;
}

export function validity(value: unknown): ValidityCommand {
  const record = body(value, ['expectedRowVersion', 'validFrom', 'validTo']);
  const validFrom = date(record, 'validFrom');
  const validTo = date(record, 'validTo');
  if (validFrom !== null && validTo !== null && validTo < validFrom)
    throw new BadRequestException('validTo must not precede validFrom');
  return { expectedRowVersion: rowVersion(record, false), validFrom, validTo };
}

export function endRelationship(value: unknown): EndRelationshipCommand {
  const record = body(value, ['expectedRowVersion', 'reason']);
  const reason = record.reason;
  if (typeof reason !== 'string' || reason.trim() === '')
    throw new BadRequestException('reason must be a non-empty string');
  return { expectedRowVersion: rowVersion(record, true)!, reason: reason.trim() };
}
