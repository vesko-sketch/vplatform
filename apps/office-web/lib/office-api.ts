import { loadOfficeWebConfig } from './oidc.config';
import { getOfficeSession, validAccessToken } from './session';

export async function officeApiGet(path: string): Promise<Response> {
  const session = await getOfficeSession();
  const token = await validAccessToken(session);
  if (token === null) return Response.json({ authenticated: false }, { status: 401 });
  try {
    return await fetch(`${loadOfficeWebConfig().officeApiUrl}${path}`, {
      cache: 'no-store',
      headers: { authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    return Response.json({ error: 'Office authorization is unavailable' }, { status: 503 });
  }
}

export async function proxyOfficeJson(path: string): Promise<Response> {
  const upstream = await officeApiGet(path);
  const body = await upstream.text();
  return new Response(body, {
    headers: { 'content-type': upstream.headers.get('content-type') ?? 'application/json' },
    status: upstream.status,
  });
}
