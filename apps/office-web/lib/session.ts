import { getIronSession, type IronSession, type SessionOptions } from 'iron-session';
import { cookies } from 'next/headers';

import { loadOfficeWebConfig } from './oidc.config';
import { getOidcConfiguration, oidc } from './oidc';

export interface OfficeWebSession {
  accessToken?: string;
  codeVerifier?: string;
  expiresAt?: number;
  nonce?: string;
  preferredUsername?: string;
  refreshToken?: string;
  state?: string;
}

function options(): SessionOptions {
  const config = loadOfficeWebConfig();
  return {
    cookieName: 'vplatform_office_session',
    cookieOptions: {
      httpOnly: true,
      sameSite: 'lax',
      secure: config.baseUrl.startsWith('https://'),
    },
    password: config.sessionSecret,
    ttl: 36_000,
  };
}

export async function getOfficeSession(): Promise<IronSession<OfficeWebSession>> {
  return getIronSession<OfficeWebSession>(await cookies(), options());
}

export async function validAccessToken(
  session: IronSession<OfficeWebSession>,
): Promise<string | null> {
  const now = Math.floor(Date.now() / 1000);
  if (session.accessToken !== undefined && (session.expiresAt ?? 0) > now + 30) {
    return session.accessToken;
  }
  if (session.refreshToken === undefined) {
    session.destroy();
    return null;
  }
  try {
    const tokens = await oidc.refreshTokenGrant(await getOidcConfiguration(), session.refreshToken);
    session.accessToken = tokens.access_token;
    session.refreshToken = tokens.refresh_token ?? session.refreshToken;
    session.expiresAt = now + (tokens.expires_in ?? 300);
    await session.save();
    return session.accessToken;
  } catch {
    session.destroy();
    return null;
  }
}
