import type { PrismaClient } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';

import { PrismaExternalIdentityRepository } from './prisma-external-identity.repository.js';

describe('PrismaExternalIdentityRepository', () => {
  it('looks up only the exact issuer and subject and returns resolution state', async () => {
    const findUnique = vi.fn().mockResolvedValue({
      id: '10000000-0000-4000-8000-000000000001',
      status: 'active',
      user_id: '00000000-0000-4000-8000-000000000001',
      users: { is_active: true },
    });
    const prisma = {
      user_external_identities: { findUnique },
    } as unknown as PrismaClient;
    const repository = new PrismaExternalIdentityRepository(prisma);

    await expect(
      repository.findByIssuerAndSubject(
        'https://identity.example.test/realms/vplatform',
        'opaque-subject',
      ),
    ).resolves.toEqual({
      identityLinkId: '10000000-0000-4000-8000-000000000001',
      identityStatus: 'active',
      platformUserId: '00000000-0000-4000-8000-000000000001',
      userIsActive: true,
    });

    expect(findUnique).toHaveBeenCalledWith({
      select: {
        id: true,
        status: true,
        user_id: true,
        users: { select: { is_active: true } },
      },
      where: {
        issuer_subject: {
          issuer: 'https://identity.example.test/realms/vplatform',
          subject: 'opaque-subject',
        },
      },
    });
  });

  it('returns null for an unknown identity without fallback matching', async () => {
    const findUnique = vi.fn().mockResolvedValue(null);
    const prisma = {
      user_external_identities: { findUnique },
    } as unknown as PrismaClient;
    const repository = new PrismaExternalIdentityRepository(prisma);

    await expect(
      repository.findByIssuerAndSubject(
        'https://identity.example.test/realms/vplatform',
        'unknown-subject',
      ),
    ).resolves.toBeNull();
  });

  it('fails closed for an unsupported persisted status', async () => {
    const prisma = {
      user_external_identities: {
        findUnique: vi.fn().mockResolvedValue({
          id: '10000000-0000-4000-8000-000000000001',
          status: 'unexpected',
          user_id: '00000000-0000-4000-8000-000000000001',
          users: { is_active: true },
        }),
      },
    } as unknown as PrismaClient;
    const repository = new PrismaExternalIdentityRepository(prisma);

    await expect(
      repository.findByIssuerAndSubject(
        'https://identity.example.test/realms/vplatform',
        'opaque-subject',
      ),
    ).rejects.toThrow('Unsupported external identity status');
  });
});
