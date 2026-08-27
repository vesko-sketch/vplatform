import { Injectable } from '@nestjs/common';

import { AuthorizationRepository } from './authorization.repository.js';
import {
  type AccessCandidate,
  type ApplicationAuthorizationDecisionInput,
  type ApplicationRecord,
  type AuthorizationDecision,
  type AuthorizationDecisionInput,
  type AuthorizationReason,
  type DatedRecord,
  type FirmRecord,
  type PermissionOverrideRecord,
  type PermissionRecord,
  PLATFORM_TIME_ZONE,
  type RoleAssignmentRecord,
} from './authorization.types.js';

interface LoadedContext {
  application: ApplicationRecord;
  firm: FirmRecord;
  overrides: PermissionOverrideRecord[];
  permissions: PermissionRecord[];
  roleAssignments: RoleAssignmentRecord[];
  rolePermissionIds: Set<string>;
}

type ContextResult = { context: LoadedContext } | { reason: AuthorizationReason };

function decision(
  basePermissionGranted: boolean,
  reason: AuthorizationReason,
  diagnostics?: AuthorizationDecision['diagnostics'],
): AuthorizationDecision {
  return {
    authorizationLevel: 'base',
    basePermissionGranted,
    ...(diagnostics === undefined ? {} : { diagnostics }),
    finalResourceOperationAllowed: null,
    reason,
    requiresDomainPolicy: true,
  };
}

export function businessDateAt(evaluatedAt: Date): string {
  if (Number.isNaN(evaluatedAt.getTime())) throw new Error('evaluatedAt must be a valid date');
  const parts = new Intl.DateTimeFormat('en-CA', {
    day: '2-digit',
    month: '2-digit',
    timeZone: PLATFORM_TIME_ZONE,
    year: 'numeric',
  }).formatToParts(evaluatedAt);
  const get = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((part) => part.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function databaseDate(value: Date): string {
  return value.toISOString().slice(0, 10);
}

export function isCurrent(
  record: Pick<DatedRecord, 'validFrom' | 'validTo'>,
  date: string,
): boolean {
  return (
    (record.validFrom === null || databaseDate(record.validFrom) <= date) &&
    (record.validTo === null || databaseDate(record.validTo) >= date)
  );
}

function overrideAtSpecificity(
  current: boolean,
  overrides: PermissionOverrideRecord[],
  specificity: 'firm' | 'global',
): AuthorizationDecision | boolean {
  if (overrides.length === 0) return current;
  const allowCount = overrides.filter((item) => item.effect.toLowerCase() === 'allow').length;
  const denyCount = overrides.filter((item) => item.effect.toLowerCase() === 'deny').length;
  const unknownEffectCount = overrides.length - allowCount - denyCount;

  if (
    unknownEffectCount > 0 ||
    allowCount > 1 ||
    denyCount > 1 ||
    (allowCount > 0 && denyCount > 0)
  ) {
    return decision(false, 'inconsistent_override', { allowCount, denyCount, specificity });
  }
  if (denyCount === 1) return false;
  if (allowCount === 1) return true;
  return decision(false, 'invalid_authorization_state');
}

@Injectable()
export class AuthorizationService {
  constructor(private readonly repository: AuthorizationRepository) {}

  async can(input: AuthorizationDecisionInput): Promise<AuthorizationDecision> {
    const date = businessDateAt(input.evaluatedAt);
    const loaded = await this.loadContext(
      input.platformUserId,
      input.applicationCode,
      input.firmId,
      date,
    );
    if ('reason' in loaded) return decision(false, loaded.reason);

    const permission = loaded.context.permissions.find(
      (item) => item.code === input.permissionCode,
    );
    if (permission === undefined) {
      const existsElsewhere = await this.repository.permissionCodeExistsOutsideApplication(
        input.permissionCode,
        loaded.context.application.id,
      );
      return decision(
        false,
        existsElsewhere ? 'permission_wrong_application' : 'permission_not_found',
      );
    }
    if (permission.scopeType !== 'FIRM') return decision(false, 'permission_wrong_scope');
    return this.evaluatePermission(loaded.context, permission, input.firmId, date);
  }

  async listEffectivePermissions(
    platformUserId: string,
    applicationCode: string,
    firmId: string,
    evaluatedAt: Date,
  ): Promise<{ decision: AuthorizationDecision; permissions: string[] }> {
    const date = businessDateAt(evaluatedAt);
    const loaded = await this.loadContext(platformUserId, applicationCode, firmId, date);
    if ('reason' in loaded) return { decision: decision(false, loaded.reason), permissions: [] };

    const decisions = loaded.context.permissions
      .filter((permission) => permission.isActive && permission.scopeType === 'FIRM')
      .map((permission) => ({
        code: permission.code,
        result: this.evaluatePermission(loaded.context, permission, firmId, date),
      }));
    const inconsistent = decisions.find((item) => item.result.reason === 'inconsistent_override');
    if (inconsistent !== undefined) return { decision: inconsistent.result, permissions: [] };
    return {
      decision: decision(true, 'allowed'),
      permissions: decisions
        .filter((item) => item.result.basePermissionGranted)
        .map((item) => item.code)
        .sort(),
    };
  }

  async listApplications(platformUserId: string, evaluatedAt: Date): Promise<ApplicationRecord[]> {
    const candidates = await this.validAccessCandidates(platformUserId, evaluatedAt);
    const unique = new Map(candidates.map((item) => [item.application.id, item.application]));
    return [...unique.values()].sort((left, right) => left.code.localeCompare(right.code));
  }

  async listFirms(platformUserId: string, evaluatedAt: Date): Promise<FirmRecord[]> {
    const candidates = await this.validAccessCandidates(platformUserId, evaluatedAt);
    const unique = new Map(candidates.map((item) => [item.firm.id, item.firm]));
    return [...unique.values()].sort((left, right) => left.code.localeCompare(right.code));
  }

  async listFirmApplications(
    platformUserId: string,
    firmId: string,
    evaluatedAt: Date,
  ): Promise<ApplicationRecord[]> {
    const candidates = await this.validAccessCandidates(platformUserId, evaluatedAt);
    const unique = new Map(
      candidates
        .filter((item) => item.firm.id === firmId)
        .map((item) => [item.application.id, item.application]),
    );
    return [...unique.values()].sort((left, right) => left.code.localeCompare(right.code));
  }

  private async loadContext(
    platformUserId: string,
    applicationCode: string,
    firmId: string,
    date: string,
  ): Promise<ContextResult> {
    const user = await this.repository.findUser(platformUserId);
    if (user === null) return { reason: 'unknown_identity' };
    if (!user.isActive) return { reason: 'disabled_user' };

    const application = await this.repository.findApplication(applicationCode);
    if (application === null) return { reason: 'application_not_found' };
    if (!application.isActive) return { reason: 'inactive_application' };

    const firm = await this.repository.findFirm(firmId);
    if (firm === null) return { reason: 'firm_not_found' };
    if (!firm.isActive) return { reason: 'inactive_firm' };

    const firmApplication = await this.repository.findFirmApplication(firm.id, application.id);
    if (firmApplication === null) return { reason: 'firm_application_missing' };
    if (!firmApplication.isActive) return { reason: 'firm_application_inactive' };
    if (!isCurrent(firmApplication, date)) return { reason: 'firm_application_not_current' };

    const userApplication = await this.repository.findUserApplication(
      platformUserId,
      firm.id,
      application.id,
    );
    if (userApplication === null) return { reason: 'user_application_access_missing' };
    if (!userApplication.isActive) return { reason: 'user_application_access_inactive' };
    if (!isCurrent(userApplication, date)) return { reason: 'user_application_access_not_current' };

    const roleAssignments = (
      await this.repository.listRoleAssignments(platformUserId, firm.id)
    ).filter((item) => item.isActive && item.role.isActive && isCurrent(item, date));
    const rolePermissions = await this.repository.listRolePermissions(
      roleAssignments.map((item) => item.role.id),
    );
    const activeRoleIds = new Set(roleAssignments.map((item) => item.role.id));
    const rolePermissionIds = new Set(
      rolePermissions
        .filter(
          (item) =>
            activeRoleIds.has(item.roleId) &&
            item.isActive &&
            item.permission.isActive &&
            item.permission.scopeType === 'FIRM' &&
            item.permission.applicationId === application.id,
        )
        .map((item) => item.permission.id),
    );

    const [permissions, overrides] = await Promise.all([
      this.repository.listApplicationPermissions(application.id),
      this.repository.listOverrides(platformUserId, firm.id, application.id),
    ]);
    return {
      context: {
        application,
        firm,
        overrides,
        permissions,
        roleAssignments,
        rolePermissionIds,
      },
    };
  }

  async canAtApplicationScope(
    input: ApplicationAuthorizationDecisionInput,
  ): Promise<AuthorizationDecision> {
    const date = businessDateAt(input.evaluatedAt);
    const user = await this.repository.findUser(input.platformUserId);
    if (user === null) return decision(false, 'unknown_identity');
    if (!user.isActive) return decision(false, 'disabled_user');

    const application = await this.repository.findApplication(input.applicationCode);
    if (application === null) return decision(false, 'application_not_found');
    if (!application.isActive) return decision(false, 'inactive_application');

    const permissions = await this.repository.listApplicationPermissions(application.id);
    const permission = permissions.find((item) => item.code === input.permissionCode);
    if (permission === undefined) {
      const existsElsewhere = await this.repository.permissionCodeExistsOutsideApplication(
        input.permissionCode,
        application.id,
      );
      return decision(
        false,
        existsElsewhere ? 'permission_wrong_application' : 'permission_not_found',
      );
    }
    if (permission.scopeType !== 'APPLICATION') return decision(false, 'permission_wrong_scope');
    if (!permission.isActive) return decision(false, 'inactive_permission');

    const assignments = (
      await this.repository.listApplicationRoleAssignments(input.platformUserId, application.id)
    ).filter((item) => item.isActive && item.role.isActive && isCurrent(item, date));
    const activeRoleIds = new Set(assignments.map((item) => item.role.id));
    const rolePermissions = await this.repository.listRolePermissions([...activeRoleIds]);
    const allowed = rolePermissions.some(
      (item) =>
        activeRoleIds.has(item.roleId) &&
        item.isActive &&
        item.permission.isActive &&
        item.permission.applicationId === application.id &&
        item.permission.scopeType === 'APPLICATION' &&
        item.permission.id === permission.id,
    );
    return allowed
      ? decision(true, 'allowed')
      : decision(false, assignments.length === 0 ? 'no_active_role' : 'permission_not_granted');
  }

  private evaluatePermission(
    context: LoadedContext,
    permission: PermissionRecord,
    firmId: string,
    date: string,
  ): AuthorizationDecision {
    if (!permission.isActive) return decision(false, 'inactive_permission');
    const applicable = context.overrides.filter(
      (item) => item.permissionId === permission.id && isCurrent(item, date),
    );

    let effective = context.rolePermissionIds.has(permission.id);
    const globalResult = overrideAtSpecificity(
      effective,
      applicable.filter((item) => item.firmId === null),
      'global',
    );
    if (typeof globalResult !== 'boolean') return globalResult;
    effective = globalResult;

    const firmResult = overrideAtSpecificity(
      effective,
      applicable.filter((item) => item.firmId === firmId),
      'firm',
    );
    if (typeof firmResult !== 'boolean') return firmResult;
    effective = firmResult;

    if (effective) return decision(true, 'allowed');
    if (applicable.some((item) => item.effect.toLowerCase() === 'deny')) {
      return decision(false, 'explicit_deny');
    }
    return decision(
      false,
      context.roleAssignments.length === 0 ? 'no_active_role' : 'permission_not_granted',
    );
  }

  private async validAccessCandidates(
    platformUserId: string,
    evaluatedAt: Date,
  ): Promise<AccessCandidate[]> {
    const user = await this.repository.findUser(platformUserId);
    if (user === null || !user.isActive) return [];
    const date = businessDateAt(evaluatedAt);
    return (await this.repository.listAccessCandidates(platformUserId)).filter(
      (item) =>
        item.application.isActive &&
        item.firm.isActive &&
        item.firmApplication !== null &&
        item.firmApplication.isActive &&
        isCurrent(item.firmApplication, date) &&
        item.userApplication.isActive &&
        isCurrent(item.userApplication, date),
    );
  }
}
