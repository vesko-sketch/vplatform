import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./oidc.config', () => ({
  loadOfficeWebConfig: (): { officeApiUrl: string } => ({
    officeApiUrl: 'http://office-api.internal:3002',
  }),
}));
vi.mock('./session', () => ({
  getOfficeSession: vi.fn().mockResolvedValue({ encrypted: true }),
  validAccessToken: vi.fn().mockResolvedValue('server-only-token'),
}));

import { proxyOfficeJson } from './office-api';

describe('Office administration BFF transport', () => {
  beforeEach(() => vi.unstubAllGlobals());

  it('forwards the server-held token without exposing it in the browser response', async () => {
    const fetchMock = vi.fn().mockResolvedValue(Response.json({ permissions: ['firms.create'] }));
    vi.stubGlobal('fetch', fetchMock);
    const response = await proxyOfficeJson('/office/me/applications/OFFICE/permissions');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://office-api.internal:3002/office/me/applications/OFFICE/permissions',
      expect.objectContaining({ headers: { authorization: 'Bearer server-only-token' } }),
    );
    expect(await response.text()).not.toContain('server-only-token');
  });
});
