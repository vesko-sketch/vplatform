export const PLATFORM_TIME_ZONE = 'Europe/Sofia';

export type AuthorizationReason =
  | 'allowed'
  | 'unknown_identity'
  | 'identity_link_disabled'
  | 'identity_unlinked'
  | 'disabled_user'
  | 'application_not_found'
  | 'inactive_application'
  | 'firm_not_found'
  | 'inactive_firm'
  | 'firm_application_missing'
  | 'firm_application_inactive'
  | 'firm_application_not_current'
  | 'user_application_access_missing'
  | 'user_application_access_inactive'
  | 'user_application_access_not_current'
  | 'permission_not_found'
  | 'inactive_permission'
  | 'permission_wrong_application'
  | 'permission_wrong_scope'
  | 'no_active_role'
  | 'permission_not_granted'
  | 'explicit_deny'
  | 'inconsistent_override'
  | 'invalid_authorization_state';

export interface AuthorizationDecision {
  authorizationLevel: 'base';
  basePermissionGranted: boolean;
  finalResourceOperationAllowed: null;
  requiresDomainPolicy: true;
  reason: AuthorizationReason;
  diagnostics?: {
    allowCount: number;
    denyCount: number;
    specificity: 'firm' | 'global';
  };
}

export interface AuthorizationDecisionInput {
  applicationCode: string;
  evaluatedAt: Date;
  firmId: string;
  permissionCode: string;
  platformUserId: string;
}

export interface DatedRecord {
  isActive: boolean;
  validFrom: Date | null;
  validTo: Date | null;
}

export interface UserRecord {
  displayName: string | null;
  email: string;
  id: string;
  isActive: boolean;
}

export interface ApplicationRecord {
  accessZone: string;
  code: string;
  id: string;
  isActive: boolean;
  name: string;
}

export interface FirmRecord {
  code: string;
  id: string;
  isActive: boolean;
  name: string;
  shortName: string | null;
}

export interface PermissionRecord {
  applicationId: string;
  code: string;
  id: string;
  isActive: boolean;
  scopeType: 'APPLICATION' | 'FIRM';
}

export interface ApplicationAuthorizationDecisionInput {
  applicationCode: string;
  evaluatedAt: Date;
  permissionCode: string;
  platformUserId: string;
}

export interface RoleAssignmentRecord extends DatedRecord {
  id: string;
  role: {
    code: string;
    id: string;
    isActive: boolean;
  };
}

export interface RolePermissionRecord {
  isActive: boolean;
  permission: PermissionRecord;
  roleId: string;
}

export interface PermissionOverrideRecord {
  effect: string;
  firmId: string | null;
  id: string;
  permissionId: string;
  validFrom: Date | null;
  validTo: Date | null;
}

export interface AccessCandidate {
  application: ApplicationRecord;
  firm: FirmRecord;
  firmApplication: DatedRecord | null;
  userApplication: DatedRecord;
}
