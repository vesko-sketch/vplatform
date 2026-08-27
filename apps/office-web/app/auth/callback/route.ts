import { redirect } from 'next/navigation';
import type { NextRequest } from 'next/server';

import { loadOfficeWebConfig } from '../../../lib/oidc.config';
import { getOidcConfiguration, oidc } from '../../../lib/oidc';
import { getOfficeSession } from '../../../lib/session';

export async function GET(request: NextRequest): Promise<never> {
  const session = await getOfficeSession();
  if (
    session.codeVerifier === undefined ||
    session.state === undefined ||
    session.nonce === undefined
  ) {
    session.destroy();
    redirect('/?authError=invalid_callback');
  }
  try {
    const tokens = await oidc.authorizationCodeGrant(
      await getOidcConfiguration(),
      new URL(request.url),
      {
        expectedNonce: session.nonce,
        expectedState: session.state,
        idTokenExpected: true,
        pkceCodeVerifier: session.codeVerifier,
      },
    );
    const claims = tokens.claims();
    session.accessToken = tokens.access_token;
    session.refreshToken = tokens.refresh_token;
    session.expiresAt = Math.floor(Date.now() / 1000) + (tokens.expires_in ?? 300);
    session.preferredUsername =
      typeof claims?.preferred_username === 'string' ? claims.preferred_username : undefined;
    session.codeVerifier = undefined;
    session.state = undefined;
    session.nonce = undefined;
    await session.save();
  } catch (error) {
    console.error('Office OIDC callback failed', {
      code:
        typeof error === 'object' && error !== null && 'code' in error
          ? String(error.code)
          : undefined,
      name: error instanceof Error ? error.name : 'UnknownError',
    });
    session.destroy();
    redirect('/?authError=authentication_failed');
  }
  redirect(loadOfficeWebConfig().baseUrl);
}
