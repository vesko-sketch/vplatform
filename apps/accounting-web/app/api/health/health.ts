export interface WebHealthResponse {
  service: 'accounting-web';
  status: 'ok';
  zone: 'private';
}

export function getHealth(): WebHealthResponse {
  return { service: 'accounting-web', status: 'ok', zone: 'private' };
}
