import { describe, expect, it, vi } from 'vitest';

vi.mock('../../../../../lib/office-api', () => ({
  proxyOfficeRequest: vi.fn().mockResolvedValue(Response.json({ ok: true })),
}));

import { proxyOfficeRequest } from '../../../../../lib/office-api';
import { GET, POST } from './route';

describe('allowlisted administration BFF proxy', () => {
  it('forwards approved administration paths through the server session', async () => {
    await GET(new Request('http://local'), { params: Promise.resolve({ segments: ['firms'] }) });
    expect(proxyOfficeRequest).toHaveBeenCalledWith('/office/admin/firms', 'GET', undefined);
  });

  it('forwards command bodies without exposing database or bearer credentials', async () => {
    await POST(new Request('http://local', { body: '{}', method: 'POST' }), {
      params: Promise.resolve({ segments: ['users', 'invitations'] }),
    });
    expect(proxyOfficeRequest).toHaveBeenCalledWith(
      '/office/admin/users/invitations',
      'POST',
      '{}',
    );
  });

  it('rejects arbitrary and Accounting administration paths', async () => {
    const response = await GET(new Request('http://local'), {
      params: Promise.resolve({ segments: ['accounting', 'periods'] }),
    });
    expect(response.status).toBe(404);
  });
});
