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

export function publicUser(value: UserAdminView): Record<string, unknown> {
  return { ...value, rowVersion: value.rowVersion.toString() };
}

export function publicInvitation(value: InvitationView): Record<string, unknown> {
  return { ...value, rowVersion: value.rowVersion.toString() };
}
