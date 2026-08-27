import { redirect } from 'next/navigation';

import { loadOfficeWebConfig } from '../../../lib/oidc.config';
import { getOidcConfiguration, oidc } from '../../../lib/oidc';
import { getOfficeSession } from '../../../lib/session';

export async function GET(): Promise<never> {
  const config = loadOfficeWebConfig();
  const session = await getOfficeSession();
  session.codeVerifier = oidc.randomPKCECodeVerifier();
  session.state = oidc.randomState();
  session.nonce = oidc.randomNonce();
  await session.save();
  const challenge = await oidc.calculatePKCECodeChallenge(session.codeVerifier);
  redirect(
    oidc
      .buildAuthorizationUrl(await getOidcConfiguration(), {
        code_challenge: challenge,
        code_challenge_method: 'S256',
        nonce: session.nonce,
        redirect_uri: `${config.baseUrl}/auth/callback`,
        scope: 'openid profile',
        state: session.state,
      })
      .toString(),
  );
}
