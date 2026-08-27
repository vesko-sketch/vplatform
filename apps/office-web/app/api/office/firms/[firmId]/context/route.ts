import type { NextRequest } from 'next/server';

import { proxyOfficeJson } from '../../../../../../lib/office-api';

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ firmId: string }> },
): Promise<Response> {
  const { firmId } = await context.params;
  return proxyOfficeJson(`/office/firms/${encodeURIComponent(firmId)}/context`);
}
