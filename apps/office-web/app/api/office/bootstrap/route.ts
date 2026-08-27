import { officeApiGet } from '../../../../lib/office-api';

export async function GET(): Promise<Response> {
  const [me, firms] = await Promise.all([
    officeApiGet('/office/me'),
    officeApiGet('/office/firms'),
  ]);
  if (!me.ok) return me;
  if (!firms.ok) return firms;
  const identity = (await me.json()) as unknown;
  const accessibleFirms = (await firms.json()) as unknown;
  return Response.json({ firms: accessibleFirms, identity });
}
