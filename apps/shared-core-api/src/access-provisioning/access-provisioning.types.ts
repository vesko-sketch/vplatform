import type { AuditContext } from '../firms/firm.types.js';

export interface ValidityCommand {
  expectedRowVersion?: bigint;
  validFrom: string | null;
  validTo: string | null;
}

export interface EndRelationshipCommand {
  expectedRowVersion: bigint;
  reason: string;
}

export interface ProvisioningContext extends AuditContext {
  evaluatedAt: Date;
}

export interface FirmApplicationView {
  applicationCode: string;
  applicationId: string;
  applicationName?: string;
  createdAt?: Date;
  id: string;
  isActive: boolean;
  rowVersion: bigint;
  updatedAt?: Date;
  validFrom: Date | null;
  validTo: Date | null;
}

export interface UserApplicationAccessView extends FirmApplicationView {
  displayName?: string | null;
  email?: string;
  userId: string;
}

export interface UserFirmRoleView {
  createdAt?: Date;
  id: string;
  isActive: boolean;
  roleCode: string;
  roleId: string;
  roleName?: string;
  rowVersion: bigint;
  updatedAt?: Date;
  userId: string;
  validFrom: Date | null;
  validTo: Date | null;
}

export type RelationshipView = FirmApplicationView | UserApplicationAccessView | UserFirmRoleView;

export function relationshipResponse<T extends RelationshipView>(
  value: T,
): Record<string, unknown> {
  return {
    ...value,
    ...(value.createdAt === undefined ? {} : { createdAt: value.createdAt.toISOString() }),
    rowVersion: value.rowVersion.toString(),
    ...(value.updatedAt === undefined ? {} : { updatedAt: value.updatedAt.toISOString() }),
    validFrom: value.validFrom?.toISOString().slice(0, 10) ?? null,
    validTo: value.validTo?.toISOString().slice(0, 10) ?? null,
  };
}
