import { describe, expect, it, vi } from 'vitest';

vi.mock('../../../../../lib/office-api', () => ({
  proxyOfficeJson: vi.fn().mockResolvedValue(Response.json([])),
}));

import { proxyOfficeJson } from '../../../../../lib/office-api';
import { GET } from './route';

describe('firm role catalog BFF route', () => {
  it('delegates to Office API through the server-side session transport', async () => {
    await GET();
    expect(proxyOfficeJson).toHaveBeenCalledWith('/office/admin/roles');
  });
});
