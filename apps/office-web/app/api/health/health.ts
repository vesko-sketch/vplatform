export interface WebHealthResponse {
  service: 'office-web';
  status: 'ok';
  zone: 'public';
}

export function getHealth(): WebHealthResponse {
  return { service: 'office-web', status: 'ok', zone: 'public' };
}
