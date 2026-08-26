import type { PrismaClient } from '@prisma/client';

import type {
  ExternalIdentityRepository,
  ExternalIdentityResolution,
  ExternalIdentityStatus,
} from './external-identity.repository.js';

const knownStatuses = new Set<ExternalIdentityStatus>(['active', 'disabled', 'unlinked']);

function asExternalIdentityStatus(value: string): ExternalIdentityStatus {
  if (!knownStatuses.has(value as ExternalIdentityStatus)) {
    throw new Error(`Unsupported external identity status: ${value}`);
  }
  return value as ExternalIdentityStatus;
}

export class PrismaExternalIdentityRepository implements ExternalIdentityRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findByIssuerAndSubject(
    issuer: string,
    subject: string,
  ): Promise<ExternalIdentityResolution | null> {
    const identity = await this.prisma.user_external_identities.findUnique({
      select: {
        id: true,
        status: true,
        user_id: true,
        users: { select: { is_active: true } },
      },
      where: { issuer_subject: { issuer, subject } },
    });

    if (identity === null) {
      return null;
    }

    return {
      identityLinkId: identity.id,
      identityStatus: asExternalIdentityStatus(identity.status),
      platformUserId: identity.user_id,
      userIsActive: identity.users.is_active,
    };
  }
}
