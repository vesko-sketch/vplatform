import { proxyOfficeJson } from '../../../../../../../lib/office-api';

export async function GET(
  _request: Request,
  context: { params: Promise<{ userId: string }> },
): Promise<Response> {
  const { userId } = await context.params;
  return proxyOfficeJson(`/office/admin/users/${encodeURIComponent(userId)}/access`);
}
