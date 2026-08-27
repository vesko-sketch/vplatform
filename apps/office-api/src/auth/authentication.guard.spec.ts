import { UnauthorizedException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';

import { OfficeAuthenticationGuard } from './authentication.guard.js';

function context(authorization?: string): { request: Record<string, unknown>; value: never } {
  const request = { headers: { authorization } };
  return {
    request,
    value: { switchToHttp: () => ({ getRequest: () => request }) } as never,
  };
}

describe('OfficeAuthenticationGuard', () => {
  it('attaches safe claims and the validated token for controlled forwarding', async () => {
    const verifier = {
      verify: vi
        .fn()
        .mockResolvedValue({ audience: ['office-api'], issuer: 'issuer', subject: 'sub' }),
    };
    const guard = new OfficeAuthenticationGuard(verifier as never);
    const test = context('Bearer signed-token');
    await expect(guard.canActivate(test.value)).resolves.toBe(true);
    expect(test.request).toMatchObject({
      bearerToken: 'signed-token',
      authentication: { subject: 'sub' },
    });
  });

  it.each([undefined, 'malformed', 'Basic credentials'])(
    'rejects missing or malformed bearer input',
    async (value) => {
      const guard = new OfficeAuthenticationGuard({ verify: vi.fn() } as never);
      await expect(guard.canActivate(context(value).value)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    },
  );

  it('rejects verifier failures such as wrong issuer or audience', async () => {
    const guard = new OfficeAuthenticationGuard({
      verify: vi.fn().mockRejectedValue(new Error('invalid')),
    } as never);
    await expect(guard.canActivate(context('Bearer invalid-token').value)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
