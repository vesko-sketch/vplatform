export interface PermissionContext {
  application: { code: string; name: string };
  permissions: string[];
}
export interface Firm {
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
export interface User {
  createdAt: string;
  currentInvitationExpiresAt: string | null;
  currentInvitationState: string | null;
  displayName: string | null;
  email: string;
  id: string;
  identityLinked: boolean;
  isActive: boolean;
  lifecycleStatus: 'ACTIVE' | 'DISABLED' | 'INVITED';
  rowVersion: string;
  updatedAt: string;
}
export interface Invitation {
  cancelledAt: string | null;
  cancellationReason: string | null;
  consumedAt: string | null;
  createdAt: string;
  expiresAt: string;
  id: string;
  invitedEmail: string;
  rowVersion: string;
  status: 'CANCELLED' | 'CONSUMED' | 'PENDING';
  updatedAt: string;
}
export interface ReferenceItem {
  code?: string;
  fullName?: string;
  id: string;
  iso2Code?: string;
  name?: string;
  nameBg?: string;
  nameEn?: string;
  shortName?: string;
}
export interface Role {
  code: string;
  id: string;
  name: string;
}
export interface Relationship {
  applicationCode?: string;
  id: string;
  isActive: boolean;
  roleCode?: string;
  roleName?: string;
  rowVersion: string;
  userDisplayName?: string | null;
  userEmail?: string;
  userId?: string;
  validFrom: string | null;
  validTo: string | null;
}
export interface UserAccess {
  applicationRoles: Array<{ applicationCode: string; roleCode: string }>;
  firms: Array<{
    applications: Array<{ applicationCode: string }>;
    firm: { code: string; id: string; name: string };
    roles: Array<{ roleCode: string; roleName: string }>;
  }>;
  userId: string;
}
