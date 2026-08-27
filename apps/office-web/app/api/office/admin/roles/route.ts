import { proxyOfficeJson } from '../../../../../lib/office-api';

export async function GET(): Promise<Response> {
  return proxyOfficeJson('/office/admin/roles');
}
