#!/usr/bin/env node

import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';

const repositoryRoot = resolve(import.meta.dirname, '../..');
const secretFile = resolve(repositoryRoot, '.env.shared-core.local');
const requiredDatabaseVariables = [
  'SHARED_CORE_DATABASE_URL',
  'SHARED_CORE_FIRM_WRITER_DATABASE_URL',
  'SHARED_CORE_ACCESS_WRITER_DATABASE_URL',
  'SHARED_CORE_USER_WRITER_DATABASE_URL',
];

function readSecrets() {
  const values = new Map();
  for (const line of readFileSync(secretFile, 'utf8').split(/\r?\n/)) {
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator > 0) values.set(line.slice(0, separator), line.slice(separator + 1));
  }
  for (const name of requiredDatabaseVariables) {
    if (!values.get(name)) throw new Error(`Missing ${name} in .env.shared-core.local`);
  }
  return Object.fromEntries(requiredDatabaseVariables.map((name) => [name, values.get(name)]));
}

async function assertPortAvailable(port) {
  await new Promise((resolvePromise, reject) => {
    const server = createServer();
    server.once('error', () => reject(new Error(`Required development port ${port} is in use`)));
    server.once('listening', () => server.close(resolvePromise));
    server.listen(port, '127.0.0.1');
  });
}

for (const port of [3100, 3101, 3102]) await assertPortAvailable(port);
const databaseEnvironment = readSecrets();
const applicationBaseEnvironment = Object.fromEntries(
  Object.entries(process.env).filter(([name]) => !name.endsWith('_DATABASE_URL')),
);
const commonOidc = {
  OIDC_CLOCK_TOLERANCE_SECONDS: '5',
  OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
};
const processes = [
  {
    filter: '@vplatform/shared-core-api',
    script: 'start',
    environment: {
      ...commonOidc,
      ...databaseEnvironment,
      INVITATION_DEVELOPMENT_RESPONSE_ENABLED: 'true',
      INVITATION_REDEMPTION_BASE_URL: 'http://localhost:3100/invitations/redeem',
      OIDC_SHARED_CORE_API_AUDIENCE: 'shared-core-api',
      OIDC_SHARED_CORE_API_CLIENT_ID: 'shared-core-api',
      OIDC_SHARED_CORE_API_SIGNING_ALGORITHM: 'RS256',
      SHARED_CORE_API_PORT: '3102',
    },
  },
  {
    filter: '@vplatform/office-api',
    script: 'start',
    environment: {
      ...commonOidc,
      OFFICE_API_PORT: '3101',
      OFFICE_WEB_ORIGIN: 'http://localhost:3100',
      OIDC_OFFICE_API_AUDIENCE: 'office-api',
      OIDC_OFFICE_API_CLIENT_ID: 'office-api',
      OIDC_OFFICE_API_SIGNING_ALGORITHM: 'RS256',
      SHARED_CORE_API_URL: 'http://localhost:3102',
    },
  },
  {
    filter: '@vplatform/office-web',
    script: 'dev',
    environment: {
      OFFICE_API_URL: 'http://localhost:3101',
      OFFICE_OIDC_CLIENT_ID: 'office-web',
      OFFICE_OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
      OFFICE_WEB_BASE_URL: 'http://localhost:3100',
      OFFICE_WEB_PORT: '3100',
      OFFICE_WEB_SESSION_SECRET: randomBytes(36).toString('base64url'),
    },
  },
];

const children = processes.map(({ filter, script, environment }) =>
  spawn('pnpm', ['--filter', filter, script], {
    cwd: repositoryRoot,
    env: { ...applicationBaseEnvironment, ...environment },
    stdio: 'inherit',
  }),
);

function stop(signal) {
  for (const child of children) child.kill(signal);
}
process.once('SIGINT', () => stop('SIGINT'));
process.once('SIGTERM', () => stop('SIGTERM'));
for (const child of children) {
  child.once('exit', (code) => {
    if (code && code !== 0) {
      stop('SIGTERM');
      process.exitCode = code;
    }
  });
}
