export interface WorkerHealth {
  service: 'document-worker';
  status: 'ready';
  domain: 'office';
}

export function getWorkerHealth(): WorkerHealth {
  return { service: 'document-worker', status: 'ready', domain: 'office' };
}
