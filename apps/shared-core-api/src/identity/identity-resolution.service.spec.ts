import { ForbiddenException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';

import type { AuthenticationClaims } from '../auth/auth.types.js';
import { IdentityResolutionService } from './identity-resolution.service.js';
import type { ExternalIdentityResolution } from './external-identity.repository.js';
import type { PrismaExternalIdentityRepository } from './prisma-external-identity.repository.js';

const claims: AuthenticationClaims = {
  audience: ['shared-core-api'],
  issuer: 'https://identity.example.test/realms/vplatform',
  preferredUsername: 'display-only',
  subject: 'opaque-keycloak-subject',
};

function createService(resolution: ExternalIdentityResolution | null): {
  findByIssuerAndSubject: ReturnType<typeof vi.fn>;
  service: IdentityResolutionService;
} {
  const findByIssuerAndSubject = vi.fn().mockResolvedValue(resolution);
  const repository = { findByIssuerAndSubject } as unknown as PrismaExternalIdentityRepository;
  return {
    findByIssuerAndSubject,
    service: new IdentityResolutionService(repository),
  };
}

async function expectDenial(
  resolution: ExternalIdentityResolution | null,
  code: string,
): Promise<void> {
  const { service } = createService(resolution);
  try {
    await service.resolve(claims);
    throw new Error('Expected identity resolution to be denied');
  } catch (error) {
    expect(error).toBeInstanceOf(ForbiddenException);
    expect((error as ForbiddenException).getResponse()).toMatchObject({ code, statusCode: 403 });
  }
}

describe('IdentityResolutionService', () => {
  it('denies an unknown identity without email or username fallback', async () => {
    const { findByIssuerAndSubject, service } = createService(null);
    await expect(service.resolve(claims)).rejects.toBeInstanceOf(ForbiddenException);
    expect(findByIssuerAndSubject).toHaveBeenCalledWith(claims.issuer, claims.subject);
    expect(findByIssuerAndSubject).toHaveBeenCalledTimes(1);
  });

  it('returns IDENTITY_NOT_LINKED for an unknown identity', async () => {
    await expectDenial(null, 'IDENTITY_NOT_LINKED');
  });

  it('returns IDENTITY_LINK_DISABLED for a disabled link', async () => {
    await expectDenial(
      {
        identityLinkId: '10000000-0000-4000-8000-000000000001',
        identityStatus: 'disabled',
        platformUserId: '00000000-0000-4000-8000-000000000001',
        userIsActive: true,
      },
      'IDENTITY_LINK_DISABLED',
    );
  });

  it('returns IDENTITY_UNLINKED for an unlinked historical identity', async () => {
    await expectDenial(
      {
        identityLinkId: '10000000-0000-4000-8000-000000000001',
        identityStatus: 'unlinked',
        platformUserId: '00000000-0000-4000-8000-000000000001',
        userIsActive: true,
      },
      'IDENTITY_UNLINKED',
    );
  });

  it('returns PLATFORM_USER_DISABLED for an inactive platform user', async () => {
    await expectDenial(
      {
        identityLinkId: '10000000-0000-4000-8000-000000000001',
        identityStatus: 'active',
        platformUserId: '00000000-0000-4000-8000-000000000001',
        userIsActive: false,
      },
      'PLATFORM_USER_DISABLED',
    );
  });

  it('returns only authentication claims and platform identity IDs for an active user', async () => {
    const { service } = createService({
      identityLinkId: '10000000-0000-4000-8000-000000000001',
      identityStatus: 'active',
      platformUserId: '00000000-0000-4000-8000-000000000001',
      userIsActive: true,
    });

    await expect(service.resolve(claims)).resolves.toEqual({
      ...claims,
      identityLinkId: '10000000-0000-4000-8000-000000000001',
      platformUserId: '00000000-0000-4000-8000-000000000001',
    });
  });
});
