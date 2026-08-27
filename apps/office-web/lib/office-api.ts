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
  return proxyOfficeRequest(path, 'GET');
}

export async function proxyOfficeRequest(
  path: string,
  method: 'GET' | 'PATCH' | 'POST',
  body?: string,
): Promise<Response> {
  const session = await getOfficeSession();
  const token = await validAccessToken(session);
  if (token === null) return Response.json({ authenticated: false }, { status: 401 });
  let upstream: Response;
  try {
    upstream = await fetch(`${loadOfficeWebConfig().officeApiUrl}${path}`, {
      ...(body === undefined ? {} : { body }),
      cache: 'no-store',
      headers: {
        authorization: `Bearer ${token}`,
        ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      },
      method,
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    return Response.json({ error: 'Office authorization is unavailable' }, { status: 503 });
  }
  const responseBody = await upstream.text();
  return new Response(responseBody, {
    headers: { 'content-type': upstream.headers.get('content-type') ?? 'application/json' },
    status: upstream.status,
  });
}
