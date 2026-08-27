import { proxyOfficeRequest } from '../../../../../lib/office-api';

const allowed = [
  /^firms(?:\/[0-9a-f-]{36})?(?:\/(?:profile|identity|settings|activate|deactivate))?$/i,
  /^firms\/[0-9a-f-]{36}\/applications(?:\/OFFICE(?:\/(?:enable|disable|users(?:\/[0-9a-f-]{36}\/(?:grant|revoke))?))?)?$/i,
  /^firms\/[0-9a-f-]{36}\/users\/[0-9a-f-]{36}\/roles(?:\/[a-z_]+\/(?:assign|remove))?$/i,
  /^users(?:\/[0-9a-f-]{36})?(?:\/access|\/invitations(?:\/[0-9a-f-]{36}\/cancel|\/reissue)?|\/(?:disable|reactivate))?$/i,
  /^users\/invitations$/i,
];

async function forward(
  request: Request,
  context: { params: Promise<{ segments: string[] }> },
  method: 'GET' | 'PATCH' | 'POST',
): Promise<Response> {
  const path = (await context.params).segments.join('/');
  if (!allowed.some((pattern) => pattern.test(path)))
    return Response.json({ error: 'Administration route is not available' }, { status: 404 });
  return proxyOfficeRequest(
    `/office/admin/${path.split('/').map(encodeURIComponent).join('/')}`,
    method,
    method === 'GET' ? undefined : await request.text(),
  );
}

export function GET(
  request: Request,
  context: { params: Promise<{ segments: string[] }> },
): Promise<Response> {
  return forward(request, context, 'GET');
}
export function PATCH(
  request: Request,
  context: { params: Promise<{ segments: string[] }> },
): Promise<Response> {
  return forward(request, context, 'PATCH');
}
export function POST(
  request: Request,
  context: { params: Promise<{ segments: string[] }> },
): Promise<Response> {
  return forward(request, context, 'POST');
}
