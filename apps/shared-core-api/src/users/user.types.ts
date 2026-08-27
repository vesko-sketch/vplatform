export interface UserAdminContext {
  actorUserId: string;
  correlationId: string;
  evaluatedAt: Date;
  requestId: string;
}

export interface UserAdminView {
  createdAt: Date;
  currentInvitationExpiresAt: Date | null;
  currentInvitationState: string | null;
  displayName: string | null;
  email: string;
  id: string;
  identityLinked: boolean;
  isActive: boolean;
  lifecycleStatus: string;
  rowVersion: bigint;
  updatedAt: Date;
}

export interface InvitationView {
  cancelledAt: Date | null;
  cancellationReason: string | null;
  consumedAt: Date | null;
  createdAt: Date;
  expiresAt: Date;
  id: string;
  invitedEmail: string;
  rowVersion: bigint;
  status: string;
  updatedAt: Date;
}

export interface CreateInvitationCommand {
  displayName: string;
  email: string;
}

export interface VersionedReasonCommand {
  expectedRowVersion: bigint;
  reason: string;
}

export interface InvitationResult {
  invitation: InvitationView;
  invitationUrl?: string;
  user: UserAdminView;
}

export interface UserAccessView {
  applicationRoles: Array<{
    applicationCode: string;
    isActive: true;
    roleCode: string;
    validFrom: Date | null;
    validTo: Date | null;
  }>;
  firms: Array<{
    applications: Array<{
      accessActive: true;
      applicationCode: string;
      validFrom: Date | null;
      validTo: Date | null;
    }>;
    firm: { code: string; id: string; name: string };
    roles: Array<{
      isActive: true;
      roleCode: string;
      roleName: string;
      validFrom: Date | null;
      validTo: Date | null;
    }>;
  }>;
  userId: string;
}

export function publicUser(value: UserAdminView): Record<string, unknown> {
  return { ...value, rowVersion: value.rowVersion.toString() };
}

export function publicInvitation(value: InvitationView): Record<string, unknown> {
  return { ...value, rowVersion: value.rowVersion.toString() };
}
