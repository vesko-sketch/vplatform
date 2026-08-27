import { proxyOfficeJson } from '../../../../../lib/office-api';

const catalogs = new Set(['countries', 'currencies', 'languages', 'legal-forms']);

export async function GET(
  _request: Request,
  context: { params: Promise<{ catalog: string }> },
): Promise<Response> {
  const { catalog } = await context.params;
  if (!catalogs.has(catalog))
    return Response.json({ error: 'Unknown reference catalog' }, { status: 404 });
  return proxyOfficeJson(`/office/reference-data/${encodeURIComponent(catalog)}`);
}
