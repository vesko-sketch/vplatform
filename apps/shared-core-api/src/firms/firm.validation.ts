import { BadRequestException } from '@nestjs/common';

import type {
  CreateFirmCommand,
  FirmLifecycleCommand,
  UpdateFirmIdentityCommand,
  UpdateFirmProfileCommand,
  UpdateFirmSettingsCommand,
} from './firm.types.js';

type Body = Record<string, unknown>;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function body(value: unknown, allowed: readonly string[]): Body {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new BadRequestException('Request body must be an object');
  }
  const record = value as Body;
  const unknown = Object.keys(record).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) throw new BadRequestException(`Unknown field: ${unknown[0]}`);
  return record;
}

function text(record: Body, key: string, required = false, maxLength?: number): string | undefined {
  const value = record[key];
  if (value === undefined && !required) return undefined;
  if (typeof value !== 'string' || value.trim() === '') {
    throw new BadRequestException(`${key} must be a non-empty string`);
  }
  const normalized = value.trim();
  if (maxLength !== undefined && normalized.length > maxLength)
    throw new BadRequestException(`${key} is too long`);
  return normalized;
}

function nullableText(record: Body, key: string, maxLength?: number): string | null | undefined {
  if (!(key in record)) return undefined;
  if (record[key] === null) return null;
  return text(record, key, false, maxLength);
}

function uuidValue(record: Body, key: string, required = false): string | undefined {
  const value = text(record, key, required);
  if (value !== undefined && !uuid.test(value))
    throw new BadRequestException(`${key} must be a UUID`);
  return value;
}

function nullableUuid(record: Body, key: string): string | null | undefined {
  if (!(key in record)) return undefined;
  if (record[key] === null) return null;
  return uuidValue(record, key, true);
}

function version(record: Body): bigint {
  const value = record.expectedRowVersion;
  if (
    (typeof value !== 'number' && typeof value !== 'string') ||
    !/^[1-9][0-9]*$/.test(String(value))
  ) {
    throw new BadRequestException('expectedRowVersion must be a positive integer');
  }
  return BigInt(value);
}

function requireChange(record: Body, keys: readonly string[]): void {
  if (!keys.some((key) => key in record))
    throw new BadRequestException('At least one change is required');
}

export function createFirm(value: unknown): CreateFirmCommand {
  const record = body(value, [
    'code',
    'name',
    'short_name',
    'legal_form_id',
    'country_id',
    'registration_number',
    'default_language_id',
    'base_currency_id',
    'timezone',
  ]);
  return {
    baseCurrencyId: uuidValue(record, 'base_currency_id', true)!,
    code: text(record, 'code', true, 50)!,
    countryId: uuidValue(record, 'country_id', true)!,
    defaultLanguageId: nullableUuid(record, 'default_language_id'),
    legalFormId: nullableUuid(record, 'legal_form_id'),
    name: text(record, 'name', true, 255)!,
    registrationNumber: nullableText(record, 'registration_number', 50),
    shortName: nullableText(record, 'short_name', 255),
    timezone: text(record, 'timezone', false, 100),
  };
}

export function updateProfile(value: unknown): UpdateFirmProfileCommand {
  const record = body(value, [
    'expectedRowVersion',
    'name',
    'short_name',
    'default_language_id',
    'timezone',
  ]);
  requireChange(record, ['name', 'short_name', 'default_language_id', 'timezone']);
  return {
    defaultLanguageId: nullableUuid(record, 'default_language_id'),
    expectedRowVersion: version(record),
    name: text(record, 'name', false, 255),
    shortName: nullableText(record, 'short_name', 255),
    timezone: text(record, 'timezone', false, 100),
  };
}

export function updateIdentity(value: unknown): UpdateFirmIdentityCommand {
  const record = body(value, [
    'expectedRowVersion',
    'code',
    'legal_form_id',
    'country_id',
    'registration_number',
  ]);
  requireChange(record, ['code', 'legal_form_id', 'country_id', 'registration_number']);
  return {
    code: text(record, 'code', false, 50),
    countryId: uuidValue(record, 'country_id'),
    expectedRowVersion: version(record),
    legalFormId: nullableUuid(record, 'legal_form_id'),
    registrationNumber: nullableText(record, 'registration_number', 50),
  };
}

export function updateSettings(value: unknown): UpdateFirmSettingsCommand {
  const record = body(value, ['expectedRowVersion', 'base_currency_id']);
  return {
    baseCurrencyId: uuidValue(record, 'base_currency_id', true)!,
    expectedRowVersion: version(record),
  };
}

export function lifecycle(value: unknown): FirmLifecycleCommand {
  const record = body(value, ['expectedRowVersion', 'reason']);
  return { expectedRowVersion: version(record), reason: text(record, 'reason', true)! };
}
