export interface FirmMaster {
  baseCurrencyId: string;
  code: string;
  countryId: string;
  createdAt: Date;
  defaultLanguageId: string | null;
  id: string;
  isActive: boolean;
  legalFormId: string | null;
  name: string;
  registrationNumber: string | null;
  rowVersion: bigint;
  shortName: string | null;
  timezone: string;
  updatedAt: Date;
}

export interface AuditContext {
  actorUserId: string;
  correlationId: string;
  requestId: string;
}

export interface CreateFirmCommand {
  baseCurrencyId: string;
  code: string;
  countryId: string;
  defaultLanguageId?: string | null;
  legalFormId?: string | null;
  name: string;
  registrationNumber?: string | null;
  shortName?: string | null;
  timezone?: string;
}

export interface UpdateFirmProfileCommand {
  defaultLanguageId?: string | null;
  expectedRowVersion: bigint;
  name?: string;
  shortName?: string | null;
  timezone?: string;
}

export interface UpdateFirmIdentityCommand {
  code?: string;
  countryId?: string;
  expectedRowVersion: bigint;
  legalFormId?: string | null;
  registrationNumber?: string | null;
}

export interface UpdateFirmSettingsCommand {
  baseCurrencyId: string;
  expectedRowVersion: bigint;
}

export interface FirmLifecycleCommand {
  expectedRowVersion: bigint;
  reason: string;
}

export interface FirmResponse {
  baseCurrencyId: string;
  code: string;
  countryId: string;
  createdAt: string;
  defaultLanguageId: string | null;
  id: string;
  isActive: boolean;
  legalFormId: string | null;
  name: string;
  registrationNumber: string | null;
  rowVersion: string;
  shortName: string | null;
  timezone: string;
  updatedAt: string;
}

export function firmResponse(firm: FirmMaster): FirmResponse {
  return {
    baseCurrencyId: firm.baseCurrencyId,
    code: firm.code,
    countryId: firm.countryId,
    createdAt: firm.createdAt.toISOString(),
    defaultLanguageId: firm.defaultLanguageId,
    id: firm.id,
    isActive: firm.isActive,
    legalFormId: firm.legalFormId,
    name: firm.name,
    registrationNumber: firm.registrationNumber,
    rowVersion: firm.rowVersion.toString(),
    shortName: firm.shortName,
    timezone: firm.timezone,
    updatedAt: firm.updatedAt.toISOString(),
  };
}
