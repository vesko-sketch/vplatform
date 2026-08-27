import { ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { HttpSharedCoreAuthorizationClient } from './shared-core.client.js';

const environment = {
  OFFICE_WEB_ORIGIN: 'http://localhost:3100',
  OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
  OIDC_OFFICE_API_AUDIENCE: 'office-api',
  OIDC_OFFICE_API_CLIENT_ID: 'office-api',
  SHARED_CORE_API_URL: 'http://shared-core.internal:3001',
};

describe('HttpSharedCoreAuthorizationClient', () => {
  beforeEach(() => {
    for (const [key, value] of Object.entries(environment)) vi.stubEnv(key, value);
  });
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it('forwards only the validated user bearer token', async () => {
    const fetchMock = vi.fn().mockResolvedValue(Response.json([{ code: 'DEV', id: 'firm-id' }]));
    vi.stubGlobal('fetch', fetchMock);
    await expect(
      new HttpSharedCoreAuthorizationClient().listFirms('validated-token'),
    ).resolves.toHaveLength(1);
    expect(fetchMock).toHaveBeenCalledWith(
      'http://shared-core.internal:3001/me/firms',
      expect.objectContaining({ headers: { authorization: 'Bearer validated-token' } }),
    );
  });

  it('requires explicit OFFICE firm access before asking for permissions', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json([{ code: 'ACCOUNTING' }])));
    await expect(
      new HttpSharedCoreAuthorizationClient().canOfficePermission(
        'token',
        'firm',
        'documents.view',
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('fails closed when Shared Core is unavailable', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network unavailable')));
    await expect(new HttpSharedCoreAuthorizationClient().listFirms('token')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('forwards firm commands with only the validated bearer token and body', async () => {
    const fetchMock = vi.fn().mockResolvedValue(Response.json({ id: 'firm-id' }));
    vi.stubGlobal('fetch', fetchMock);
    await new HttpSharedCoreAuthorizationClient().createFirm('validated-token', { code: 'TEST' });
    expect(fetchMock).toHaveBeenCalledWith(
      'http://shared-core.internal:3001/firms',
      expect.objectContaining({
        body: '{"code":"TEST"}',
        headers: { authorization: 'Bearer validated-token', 'content-type': 'application/json' },
        method: 'POST',
      }),
    );
  });

  it('delegates provisioning reads and commands without database context', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json([]))
      .mockResolvedValueOnce(Response.json({ id: 'relationship-id' }));
    vi.stubGlobal('fetch', fetchMock);
    const client = new HttpSharedCoreAuthorizationClient();
    await client.provisioningRead('firm-id/applications', 'validated-token');
    await client.provisioningCommand('firm-id/applications/OFFICE/enable', 'validated-token', {});
    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://shared-core.internal:3001/firms/firm-id/applications',
      expect.objectContaining({ headers: { authorization: 'Bearer validated-token' } }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'http://shared-core.internal:3001/firms/firm-id/applications/OFFICE/enable',
      expect.objectContaining({
        body: '{}',
        headers: { authorization: 'Bearer validated-token', 'content-type': 'application/json' },
        method: 'POST',
      }),
    );
  });

  it('delegates application permissions, reference data, and user access with only the token', async () => {
    const fetchMock = vi.fn().mockImplementation(() => Promise.resolve(Response.json([])));
    vi.stubGlobal('fetch', fetchMock);
    const client = new HttpSharedCoreAuthorizationClient();
    await client.getApplicationPermissions('token', 'OFFICE');
    await client.referenceData('countries', 'token');
    await client.userAdminRead('/user-id/access', 'token');
    const urls = fetchMock.mock.calls.map((call) => String(call[0]));
    expect(urls).toEqual([
      'http://shared-core.internal:3001/me/applications/OFFICE/permissions',
      'http://shared-core.internal:3001/reference-data/countries',
      'http://shared-core.internal:3001/users/user-id/access',
    ]);
    for (const [, options] of fetchMock.mock.calls)
      expect(options).toMatchObject({ headers: { authorization: 'Bearer token' } });
  });

  it('delegates the firm-role catalog without database context', async () => {
    const fetchMock = vi.fn().mockResolvedValue(Response.json([{ code: 'admin' }]));
    vi.stubGlobal('fetch', fetchMock);
    await new HttpSharedCoreAuthorizationClient().firmRoles('validated-token');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://shared-core.internal:3001/firm-roles',
      expect.objectContaining({ headers: { authorization: 'Bearer validated-token' } }),
    );
  });
});
