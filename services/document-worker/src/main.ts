import { getWorkerHealth } from './health.js';

// Phase 1 deliberately starts no queues and opens no database connections.
process.stdout.write(`${JSON.stringify(getWorkerHealth())}\n`);
