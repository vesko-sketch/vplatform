import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { AuthorizationRepository } from './authorization.repository.js';
import { AuthorizationService, businessDateAt, isCurrent } from './authorization.service.js';
import type {
  ApplicationRecord,
  AuthorizationDecision,
  DatedRecord,
  FirmRecord,
  PermissionOverrideRecord,
  PermissionRecord,
  RoleAssignmentRecord,
  RolePermissionRecord,
  UserRecord,
} from './authorization.types.js';

const evaluatedAt = new Date('2026-08-27T21:30:00.000Z');
const user: UserRecord = {
  displayName: 'Test User',
  email: 'ignored@example.test',
  id: '00000000-0000-4000-8000-000000000001',
  isActive: true,
};
const office: ApplicationRecord = {
  accessZone: 'PUBLIC',
  code: 'OFFICE',
  id: '00000000-0000-4000-8000-000000000002',
  isActive: true,
  name: 'V Office',
};
const firm: FirmRecord = {
  code: 'FIRM',
  id: '00000000-0000-4000-8000-000000000003',
  isActive: true,
  name: 'Test Firm',
  shortName: null,
};
const permission: PermissionRecord = {
  applicationId: office.id,
  code: 'documents.view',
  id: '00000000-0000-4000-8000-000000000004',
  isActive: true,
  scopeType: 'FIRM',
};
const current: DatedRecord = { isActive: true, validFrom: null, validTo: null };
const assignment: RoleAssignmentRecord = {
  ...current,
  id: '00000000-0000-4000-8000-000000000005',
  role: { code: 'accountant', id: '00000000-0000-4000-8000-000000000006', isActive: true },
};
const rolePermission: RolePermissionRecord = {
  isActive: true,
  permission,
  roleId: assignment.role.id,
};

type MockRepository = {
  [K in keyof AuthorizationRepository]: AuthorizationRepository[K] extends (
    ...args: never[]
  ) => unknown
    ? ReturnType<typeof vi.fn>
    : never;
};

function repository(): MockRepository {
  return {
    findApplication: vi.fn().mockResolvedValue(office),
    findFirm: vi.fn().mockResolvedValue(firm),
    findFirmApplication: vi.fn().mockResolvedValue(current),
    findUser: vi.fn().mockResolvedValue(user),
    findUserApplication: vi.fn().mockResolvedValue(current),
    listAccessCandidates: vi.fn().mockResolvedValue([]),
    listApplicationRoleAssignments: vi.fn().mockResolvedValue([]),
    listApplicationPermissions: vi.fn().mockResolvedValue([permission]),
    listOverrides: vi.fn().mockResolvedValue([]),
    listRoleAssignments: vi.fn().mockResolvedValue([assignment]),
    listRolePermissions: vi.fn().mockResolvedValue([rolePermission]),
    permissionCodeExistsOutsideApplication: vi.fn().mockResolvedValue(false),
  };
}

function override(
  effect: 'allow' | 'deny',
  firmId: string | null,
  id: string,
): PermissionOverrideRecord {
  return { effect, firmId, id, permissionId: permission.id, validFrom: null, validTo: null };
}

describe('AuthorizationService', () => {
  let repo: MockRepository;
  let service: AuthorizationService;

  beforeEach(() => {
    repo = repository();
    service = new AuthorizationService(repo as unknown as AuthorizationRepository);
  });

  const can = (): Promise<AuthorizationDecision> =>
    service.can({
      applicationCode: office.code,
      evaluatedAt,
      firmId: firm.id,
      permissionCode: permission.code,
      platformUserId: user.id,
    });

  it('derives the Europe/Sofia date once and treats DATE bounds as inclusive', () => {
    expect(businessDateAt(evaluatedAt)).toBe('2026-08-28');
    expect(
      isCurrent(
        { validFrom: new Date('2026-08-28T00:00:00Z'), validTo: new Date('2026-08-28T00:00:00Z') },
        '2026-08-28',
      ),
    ).toBe(true);
  });

  it.each([
    ['unknown_identity', 'findUser', null],
    ['disabled_user', 'findUser', { ...user, isActive: false }],
    ['application_not_found', 'findApplication', null],
    ['inactive_application', 'findApplication', { ...office, isActive: false }],
    ['firm_not_found', 'findFirm', null],
    ['inactive_firm', 'findFirm', { ...firm, isActive: false }],
    ['firm_application_missing', 'findFirmApplication', null],
    ['firm_application_inactive', 'findFirmApplication', { ...current, isActive: false }],
    ['user_application_access_missing', 'findUserApplication', null],
    ['user_application_access_inactive', 'findUserApplication', { ...current, isActive: false }],
  ] as const)('fails closed with %s', async (reason, method, value) => {
    repo[method].mockResolvedValue(value);
    await expect(can()).resolves.toMatchObject({ basePermissionGranted: false, reason });
  });

  it.each([
    ['firm_application_not_current', 'findFirmApplication'],
    ['user_application_access_not_current', 'findUserApplication'],
  ] as const)('rejects future and expired grants as %s', async (reason, method) => {
    repo[method].mockResolvedValue({ ...current, validFrom: new Date('2026-08-29T00:00:00Z') });
    await expect(can()).resolves.toMatchObject({ reason });
    repo[method].mockResolvedValue({
      ...current,
      validFrom: null,
      validTo: new Date('2026-08-27T00:00:00Z'),
    });
    await expect(can()).resolves.toMatchObject({ reason });
  });

  it('requires an active application-qualified permission', async () => {
    repo.listApplicationPermissions.mockResolvedValue([]);
    repo.permissionCodeExistsOutsideApplication.mockResolvedValue(true);
    await expect(can()).resolves.toMatchObject({ reason: 'permission_wrong_application' });
    expect(repo.permissionCodeExistsOutsideApplication).toHaveBeenCalledWith(
      permission.code,
      office.id,
    );

    repo.listApplicationPermissions.mockResolvedValue([{ ...permission, isActive: false }]);
    await expect(can()).resolves.toMatchObject({ reason: 'inactive_permission' });
  });

  it('keeps application permissions out of firm-scoped decisions', async () => {
    repo.listApplicationPermissions.mockResolvedValue([
      { ...permission, code: 'firms.create', scopeType: 'APPLICATION' },
    ]);
    await expect(
      service.can({
        applicationCode: office.code,
        evaluatedAt,
        firmId: firm.id,
        permissionCode: 'firms.create',
        platformUserId: user.id,
      }),
    ).resolves.toMatchObject({ basePermissionGranted: false, reason: 'permission_wrong_scope' });
  });

  describe('application scope', () => {
    const applicationPermission = {
      ...permission,
      code: 'firms.create',
      scopeType: 'APPLICATION' as const,
    };
    const canAtApplicationScope = (): Promise<AuthorizationDecision> =>
      service.canAtApplicationScope({
        applicationCode: office.code,
        evaluatedAt,
        permissionCode: applicationPermission.code,
        platformUserId: user.id,
      });

    beforeEach(() => {
      repo.listApplicationPermissions.mockResolvedValue([applicationPermission]);
      repo.listApplicationRoleAssignments.mockResolvedValue([assignment]);
      repo.listRolePermissions.mockResolvedValue([
        { ...rolePermission, permission: applicationPermission },
      ]);
    });

    it('enumerates only active APPLICATION permissions, deduplicated and sorted', async () => {
      const second = {
        ...applicationPermission,
        code: 'firms.catalog.view',
        id: '00000000-0000-4000-8000-000000000099',
      };
      repo.listRolePermissions.mockResolvedValue([
        { ...rolePermission, permission: applicationPermission },
        { ...rolePermission, permission: second },
        { ...rolePermission, permission: second },
        { ...rolePermission, permission },
        {
          ...rolePermission,
          isActive: false,
          permission: { ...applicationPermission, code: 'users.invite' },
        },
      ]);
      await expect(
        service.listEffectiveApplicationPermissions(user.id, office.code, evaluatedAt),
      ).resolves.toEqual({
        application: office,
        permissions: ['firms.catalog.view', 'firms.create'],
      });
      expect(repo.findFirm).not.toHaveBeenCalled();
      expect(repo.findUserApplication).not.toHaveBeenCalled();
    });

    it('returns an empty set without inferring authority from firm roles', async () => {
      repo.listApplicationRoleAssignments.mockResolvedValue([]);
      repo.listRolePermissions.mockResolvedValue([]);
      await expect(
        service.listEffectiveApplicationPermissions(user.id, office.code, evaluatedAt),
      ).resolves.toEqual({ application: office, permissions: [] });
    });

    it.each([
      ['unknown_identity', 'findUser', null],
      ['disabled_user', 'findUser', { ...user, isActive: false }],
      ['application_not_found', 'findApplication', null],
      ['inactive_application', 'findApplication', { ...office, isActive: false }],
    ] as const)('fails the application gate with %s', async (reason, method, value) => {
      repo[method].mockResolvedValue(value);
      await expect(canAtApplicationScope()).resolves.toMatchObject({ reason });
    });

    it('requires an application-qualified permission', async () => {
      repo.listApplicationPermissions.mockResolvedValue([]);
      repo.permissionCodeExistsOutsideApplication.mockResolvedValue(true);
      await expect(canAtApplicationScope()).resolves.toMatchObject({
        reason: 'permission_wrong_application',
      });
    });

    it('allows an active current application role and does not consult firm access', async () => {
      await expect(canAtApplicationScope()).resolves.toMatchObject({
        basePermissionGranted: true,
        reason: 'allowed',
      });
      expect(repo.findFirm).not.toHaveBeenCalled();
      expect(repo.findFirmApplication).not.toHaveBeenCalled();
      expect(repo.findUserApplication).not.toHaveBeenCalled();
      expect(repo.listRoleAssignments).not.toHaveBeenCalled();
      expect(repo.listOverrides).not.toHaveBeenCalled();
    });

    it('authorizes firms.activate at application scope without resolving a target firm', async () => {
      const activatePermission = {
        ...applicationPermission,
        code: 'firms.activate',
      };
      repo.listApplicationPermissions.mockResolvedValue([activatePermission]);
      repo.listRolePermissions.mockResolvedValue([
        { ...rolePermission, permission: activatePermission },
      ]);

      await expect(
        service.canAtApplicationScope({
          applicationCode: office.code,
          evaluatedAt,
          permissionCode: 'firms.activate',
          platformUserId: user.id,
        }),
      ).resolves.toMatchObject({ basePermissionGranted: true, reason: 'allowed' });
      expect(repo.findFirm).not.toHaveBeenCalled();
      expect(repo.findFirmApplication).not.toHaveBeenCalled();
      expect(repo.findUserApplication).not.toHaveBeenCalled();
    });

    it.each([
      [{ ...assignment, isActive: false }, 'no_active_role'],
      [{ ...assignment, validFrom: new Date('2026-08-29T00:00:00Z') }, 'no_active_role'],
      [{ ...assignment, validTo: new Date('2026-08-27T00:00:00Z') }, 'no_active_role'],
      [{ ...assignment, role: { ...assignment.role, isActive: false } }, 'no_active_role'],
    ] as const)('denies inactive or non-current application roles', async (value, reason) => {
      repo.listApplicationRoleAssignments.mockResolvedValue([value]);
      await expect(canAtApplicationScope()).resolves.toMatchObject({ reason });
    });

    it('denies firm permissions through the application resolver', async () => {
      repo.listApplicationPermissions.mockResolvedValue([permission]);
      await expect(
        service.canAtApplicationScope({
          applicationCode: office.code,
          evaluatedAt,
          permissionCode: permission.code,
          platformUserId: user.id,
        }),
      ).resolves.toMatchObject({ reason: 'permission_wrong_scope' });
    });

    it('denies inactive permissions and inactive role mappings', async () => {
      repo.listApplicationPermissions.mockResolvedValue([
        { ...applicationPermission, isActive: false },
      ]);
      await expect(canAtApplicationScope()).resolves.toMatchObject({
        reason: 'inactive_permission',
      });
      repo.listApplicationPermissions.mockResolvedValue([applicationPermission]);
      repo.listRolePermissions.mockResolvedValue([
        { ...rolePermission, isActive: false, permission: applicationPermission },
      ]);
      await expect(canAtApplicationScope()).resolves.toMatchObject({
        reason: 'permission_not_granted',
      });
    });
  });

  it('unions active permissions from multiple unordered roles and deduplicates them', async () => {
    const second = {
      ...assignment,
      id: '00000000-0000-4000-8000-000000000007',
      role: { code: 'manager', id: '00000000-0000-4000-8000-000000000008', isActive: true },
    };
    repo.listRoleAssignments.mockResolvedValue([second, assignment]);
    repo.listRolePermissions.mockResolvedValue([
      rolePermission,
      { ...rolePermission, roleId: second.role.id },
    ]);
    await expect(can()).resolves.toMatchObject({ basePermissionGranted: true, reason: 'allowed' });
  });

  it.each([
    [{ ...assignment, isActive: false }, 'no_active_role'],
    [{ ...assignment, validFrom: new Date('2026-08-29T00:00:00Z') }, 'no_active_role'],
    [{ ...assignment, validTo: new Date('2026-08-27T00:00:00Z') }, 'no_active_role'],
    [{ ...assignment, role: { ...assignment.role, isActive: false } }, 'no_active_role'],
  ] as const)('ignores inactive/non-current role state', async (value, reason) => {
    repo.listRoleAssignments.mockResolvedValue([value]);
    await expect(can()).resolves.toMatchObject({ basePermissionGranted: false, reason });
  });

  it('ignores inactive role-permission mappings and permissions from another application', async () => {
    repo.listRolePermissions.mockResolvedValue([{ ...rolePermission, isActive: false }]);
    await expect(can()).resolves.toMatchObject({ reason: 'permission_not_granted' });
    repo.listRolePermissions.mockResolvedValue([
      {
        ...rolePermission,
        permission: { ...permission, applicationId: '00000000-0000-4000-8000-000000000099' },
      },
    ]);
    await expect(can()).resolves.toMatchObject({ reason: 'permission_not_granted' });
  });

  it('allows an override without a role permission, but never without access gates', async () => {
    repo.listRolePermissions.mockResolvedValue([]);
    repo.listOverrides.mockResolvedValue([override('allow', null, 'global-allow')]);
    await expect(can()).resolves.toMatchObject({ basePermissionGranted: true });
    repo.findUserApplication.mockResolvedValue(null);
    await expect(can()).resolves.toMatchObject({ reason: 'user_application_access_missing' });
    expect(repo.listOverrides).toHaveBeenCalledTimes(1);
  });

  it('applies global then firm-specific override precedence', async () => {
    repo.listOverrides.mockResolvedValue([
      override('deny', null, 'global-deny'),
      override('allow', firm.id, 'firm-allow'),
    ]);
    await expect(can()).resolves.toMatchObject({ basePermissionGranted: true, reason: 'allowed' });

    repo.listOverrides.mockResolvedValue([
      override('allow', null, 'global-allow'),
      override('deny', firm.id, 'firm-deny'),
    ]);
    await expect(can()).resolves.toMatchObject({
      basePermissionGranted: false,
      reason: 'explicit_deny',
    });
  });

  it.each([
    [override('deny', null, 'global-deny'), 'explicit_deny'],
    [override('deny', firm.id, 'firm-deny'), 'explicit_deny'],
    [override('allow', null, 'global-allow'), 'allowed'],
    [override('allow', firm.id, 'firm-allow'), 'allowed'],
  ] as const)('applies a single override', async (value, reason) => {
    repo.listOverrides.mockResolvedValue([value]);
    await expect(can()).resolves.toMatchObject({ reason });
  });

  it.each([
    [[override('allow', null, 'a1'), override('allow', null, 'a2')], 2, 0],
    [[override('deny', firm.id, 'd1'), override('deny', firm.id, 'd2')], 0, 2],
    [[override('allow', null, 'a1'), override('deny', null, 'd1')], 1, 1],
  ] as const)(
    'fails closed for duplicate or conflicting overrides',
    async (values, allowCount, denyCount) => {
      repo.listOverrides.mockResolvedValue(values);
      await expect(can()).resolves.toMatchObject({
        basePermissionGranted: false,
        diagnostics: { allowCount, denyCount },
        reason: 'inconsistent_override',
      });
    },
  );

  it('reports only base authorization and leaves final resource policy unresolved', async () => {
    await expect(can()).resolves.toMatchObject({
      authorizationLevel: 'base',
      basePermissionGranted: true,
      finalResourceOperationAllowed: null,
      requiresDomainPolicy: true,
    });
  });

  it('enumerates access from explicit mappings only, never roles or firm groups', async () => {
    repo.listAccessCandidates.mockResolvedValue([
      { application: office, firm, firmApplication: current, userApplication: current },
      {
        application: office,
        firm: { ...firm, id: '00000000-0000-4000-8000-000000000009', isActive: false },
        firmApplication: current,
        userApplication: current,
      },
    ]);
    await expect(service.listFirms(user.id, evaluatedAt)).resolves.toEqual([firm]);
    expect(repo.listRoleAssignments).not.toHaveBeenCalled();
  });
});
